# Cascading Failure

## Incident: AWS US-East-1, June 29, 2012

**Severity:** Critical | **Category:** Distributed Systems / Resilience | **Impact:** Multi-hour outage affecting Netflix, Instagram, Pinterest, Heroku, and thousands of other services

---

## What Happened

On June 29, 2012, a severe thunderstorm knocked out power to AWS's primary US-East-1
data center in Northern Virginia. While the power loss itself was the trigger, the
true damage came from the cascading failure that followed. The incident became a
defining case study in distributed systems resilience.

### Timeline

1. **~8:00 PM EDT** -- Severe derecho storm hits Northern Virginia. Utility power fails at multiple AWS facilities.
2. **~8:05 PM** -- Backup generators activate. Some generators fail to start or transfer properly due to the violence of the electrical event.
3. **~8:10 PM** -- EBS (Elastic Block Store) nodes in affected zones lose power. EC2 instances begin failing.
4. **~8:15 PM** -- Services dependent on the failed instances begin timing out. Instead of failing fast, they **retry aggressively**.
5. **~8:20 PM** -- The retry storms from hundreds of services overwhelm the remaining healthy infrastructure. ELB (Elastic Load Balancing) control plane is saturated.
6. **~8:30 PM** -- The EBS control plane, overwhelmed by recovery requests and retry traffic, enters a degraded state. This prevents even healthy volumes from performing operations.
7. **~8:30-11:00 PM** -- Cascading failure fully engaged: services that were in unaffected zones fail because they depend on services in affected zones. The blast radius expands beyond the original failure domain.
8. **Recovery took over 12 hours** for full EBS restoration, because the recovery process itself generated load that competed with normal traffic.

### Scale of Impact

- Netflix, Instagram, Pinterest, and Heroku experienced significant outages.
- The incident is estimated to have affected millions of end users.
- Some customers lost EBS data that was not replicated across availability zones.

---

## Technical Root Cause

The physical trigger (power loss) was not the root cause of the cascading failure. The
root cause was the **absence of resilience patterns** in the dependency chain between
services.

### The Cascade Anatomy

```
Service A (web tier)
  └─ calls Service B (API tier) -- timeout: 30s, retries: 3
       └─ calls Service C (data tier) -- timeout: 30s, retries: 3
            └─ calls EBS (storage) -- FAILED

What happens:
1. EBS is down. Service C hangs for 30s per request.
2. Service B waits 30s for C, times out, retries 3x = 90s of waiting.
3. Service A waits for B, times out, retries 3x.
4. One user request generates: 3 (A retries) x 3 (B retries) x 3 (C retries) = 27 calls to EBS.
5. Multiply by thousands of concurrent users = retry storm.
```

### The Problematic Code Pattern

```javascript
// DANGEROUS: No circuit breaker, aggressive retry, long timeout
async function callDownstreamService(request) {
  const MAX_RETRIES = 3;
  const TIMEOUT = 30000; // 30 seconds -- way too long

  for (let attempt = 0; attempt < MAX_RETRIES; attempt++) {
    try {
      const response = await fetch('http://service-b/api/data', {
        body: JSON.stringify(request),
        signal: AbortSignal.timeout(TIMEOUT),
      });
      return await response.json();
    } catch (error) {
      console.log(`Attempt ${attempt + 1} failed, retrying...`);
      // No backoff, no circuit breaker, immediate retry
      // When service-b is down, this just hammers it harder
    }
  }
  throw new Error('Service B unavailable');
}
```

Problems in this code:
1. **30-second timeout**: Threads/connections are held open for 30s per attempt, exhausting connection pools.
2. **Immediate retry with no backoff**: Failed requests are retried instantly, amplifying load on the already-struggling downstream.
3. **No circuit breaker**: Even after 3 failures, the next incoming request will try again. There is no memory of past failures.
4. **No fallback**: The function either succeeds or throws -- there is no degraded-but-functional path.

---

## How It Was Detected

- CloudWatch metrics showed EBS API latency spike from ~5ms to timeout values.
- Service health dashboards across the region turned red in a wave pattern -- storage first, then data tier, then API tier, then web tier.
- The key signal of a cascade: **healthy services in unaffected zones started failing** because they had hard dependencies on affected-zone services.

---

## How It Was Fixed

### Fix 1: Circuit Breaker Pattern

Stop calling a service that is known to be failing. After a threshold of failures,
"open" the circuit and fail fast for a cooldown period.

```javascript
class CircuitBreaker {
  constructor(options = {}) {
    this.failureThreshold = options.failureThreshold || 5;
    this.cooldownMs = options.cooldownMs || 30000;
    this.failureCount = 0;
    this.state = 'CLOSED';  // CLOSED = normal, OPEN = failing fast, HALF_OPEN = testing
    this.lastFailureTime = null;
  }

  async call(fn) {
    if (this.state === 'OPEN') {
      if (Date.now() - this.lastFailureTime > this.cooldownMs) {
        this.state = 'HALF_OPEN';  // Allow one test request through
      } else {
        throw new Error('Circuit is OPEN -- failing fast');
      }
    }

    try {
      const result = await fn();
      this.onSuccess();
      return result;
    } catch (error) {
      this.onFailure();
      throw error;
    }
  }

  onSuccess() {
    this.failureCount = 0;
    this.state = 'CLOSED';
  }

  onFailure() {
    this.failureCount++;
    this.lastFailureTime = Date.now();
    if (this.failureCount >= this.failureThreshold) {
      this.state = 'OPEN';
    }
  }
}
```

### Fix 2: Exponential Backoff with Jitter

Space out retries and add randomness to prevent synchronized retry storms.

```javascript
async function callWithBackoff(fn, maxRetries = 3) {
  for (let attempt = 0; attempt < maxRetries; attempt++) {
    try {
      return await fn();
    } catch (error) {
      if (attempt === maxRetries - 1) throw error;
      const baseDelay = Math.pow(2, attempt) * 100; // 100ms, 200ms, 400ms
      const jitter = Math.random() * baseDelay;      // Random 0-100%, 0-200%, 0-400%
      await sleep(baseDelay + jitter);
    }
  }
}
```

### Fix 3: Timeout Budgets

Instead of each service in the chain having its own 30-second timeout, propagate a
deadline through the call chain.

```javascript
async function handleRequest(req, res) {
  const deadline = Date.now() + 5000; // 5 second total budget for entire request

  const userData = await callServiceB(req.userId, { deadline });
  // Service B receives the deadline and knows it must respond before it
  // It passes the remaining budget to Service C
  // If 4 seconds have elapsed, Service C gets a 1-second budget, not 30 seconds
}
```

### Fix 4: Bulkhead Isolation

Isolate failures so that a problem in one dependency does not consume all resources.

```javascript
// Separate thread/connection pools per downstream dependency
const serviceAPool = new ConnectionPool({ maxConnections: 20 });
const serviceBPool = new ConnectionPool({ maxConnections: 20 });

// If Service A is slow and exhausts its 20 connections,
// Service B still has its own 20 connections available.
```

---

## Key Lessons

1. **The retry storm is often worse than the original failure.** A 10% capacity loss can become a 100% outage when retries amplify the load.
2. **Timeouts are not optional.** Every network call needs a timeout, and 30 seconds is almost always too long for a synchronous service call.
3. **Circuit breakers are the seatbelts of distributed systems.** You do not notice them until the crash, and then they save everything.
4. **Design for partial failure.** The question is not "will a dependency fail?" but "when a dependency fails, what does the user experience?"
5. **Blast radius containment matters.** Bulkheads, multi-AZ deployments, and graceful degradation prevent a localized failure from becoming a global outage.

---

## Detection Guide for Claude

### Red Flags

- **Synchronous service-to-service calls with no timeout** or timeouts over 10 seconds.
- **Retry loops with no backoff**: immediate retries, fixed-delay retries, or retries without jitter.
- **No circuit breaker** around external service calls (HTTP, gRPC, database, message queue).
- **No fallback path**: the code either succeeds or throws, with no degraded-mode option.
- **Shared connection/thread pools** across multiple downstream dependencies (no bulkhead isolation).
- **Missing health checks**: no readiness or liveness probes that account for dependency health.

### Pattern to Flag

```
# Any of these patterns in service-to-service calls:
fetch(url)                          # No timeout at all
fetch(url, { timeout: 60000 })      # Timeout too long (>10s for sync calls)
for retry in range(5):              # Retry loop with no backoff
    response = call_service()
```

### Suggested Fix

Recommend: (1) circuit breaker around every external call, (2) timeouts of 1-5 seconds for synchronous calls, (3) exponential backoff with jitter on retries, (4) a fallback/degraded response path.
