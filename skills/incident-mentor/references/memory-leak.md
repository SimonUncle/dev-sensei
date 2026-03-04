# Memory Leak in Production

## Incident: Node.js Production Memory Leaks (Composite of Real Cases)

**Severity:** High | **Category:** Runtime / Resource Management | **Impact:** Gradual degradation followed by OOM kills and service restarts

---

## What Happened

Memory leaks in Node.js (and other garbage-collected runtimes) are insidious because
they do not crash immediately. They manifest as a slow bleed: RSS (Resident Set Size)
grows by a few MB per hour, and days or weeks later the process hits the container
memory limit and is OOM-killed. This composite draws from publicly documented
incidents at Walmart (2013 Node.js Black Friday leak), Netflix (event emitter leaks
in their Node.js API gateway), LinkedIn (closure-based leaks in their mobile backend),
and countless smaller companies.

### Typical Incident Timeline

1. **Day 0**: Application deployed. Memory usage: 150 MB RSS. Everything looks healthy.
2. **Day 1**: Memory at 180 MB. Within normal variance -- no alerts.
3. **Day 3**: Memory at 250 MB. Still under the 512 MB container limit.
4. **Day 7**: Memory at 400 MB. GC pauses become noticeable -- P99 latency creeps up.
5. **Day 9**: Memory at 510 MB. GC is running constantly, consuming 15% of CPU.
6. **Day 10**: OOM kill. Container restarts. Memory drops to 150 MB. The cycle begins again.
7. **Repeat**: The team adds a cron job to restart the service daily. The actual leak is never found.

### Scale of Impact

- Walmart's 2013 Node.js memory leak caused frontend servers to degrade during Black Friday traffic. The root cause was a known bug in the Node.js `Buffer` implementation at the time.
- Netflix documented event emitter leaks in their Node.js tier that caused cascading latency increases as GC pressure mounted.
- The most common symptom teams report: "The service gets slow after a few days and restarting it fixes it."

---

## Technical Root Cause

In garbage-collected languages, a memory leak means **objects that are no longer needed
are still reachable from the GC root**, so they cannot be collected. In Node.js, the
most common causes are:

### Cause 1: Event Listener Accumulation

```javascript
// LEAKING: Adding listeners without removing them
class ConnectionManager {
  constructor(eventBus) {
    this.eventBus = eventBus;
  }

  handleRequest(req, res) {
    // This adds a NEW listener on every single request
    // After 100,000 requests, there are 100,000 listeners
    this.eventBus.on('config-change', () => {
      // This closure captures req and res, preventing them from being GC'd
      res.setHeader('X-Config-Version', getConfigVersion());
    });

    // ... handle request
  }
}
// Node.js will warn: "MaxListenersExceededWarning: Possible EventEmitter memory leak"
// Many developers respond by increasing the limit instead of fixing the leak:
// eventBus.setMaxListeners(0);  // DO NOT DO THIS -- it just silences the warning
```

### Cause 2: Module-Scope Caches Without Bounds

```javascript
// LEAKING: Unbounded cache at module level
const cache = {};  // Lives for the entire process lifetime

function processRequest(req) {
  const key = req.headers['x-request-id'];
  const result = expensiveComputation(req.body);

  // Cache grows forever -- one entry per request, never evicted
  cache[key] = {
    result,
    timestamp: Date.now(),
    requestBody: req.body  // Large object held indefinitely
  };

  return result;
}
```

### Cause 3: Closures Capturing Large Objects

```javascript
// LEAKING: Closure holds reference to large data long after it's needed
function createProcessor() {
  const hugeDataset = loadEntireDataset(); // 50 MB in memory

  return function processItem(item) {
    // This closure captures hugeDataset, even if it only uses a tiny part
    return hugeDataset.metadata.version;
    // Fix: extract only what's needed BEFORE creating the closure
  };
}

// The processor function lives in a long-lived object, keeping hugeDataset alive
app.use(createProcessor());
```

### Cause 4: Uncleared Timers and Intervals

```javascript
// LEAKING: setInterval without clearInterval
class Poller {
  start(callback) {
    // If start() is called multiple times (e.g., on reconnect),
    // multiple intervals accumulate, each holding references
    this.interval = setInterval(async () => {
      const data = await fetchData();
      callback(data);
    }, 5000);
    // Previous interval is orphaned -- still running, still holding references
  }

  // Missing: stop() method that calls clearInterval(this.interval)
}
```

---

## How It Was Detected

### Monitoring Signals

- **RSS (Resident Set Size) growing linearly over time**: The defining signal. Healthy Node.js processes have stable RSS after warmup.
- **Heap Used growing while Heap Total stays flat** (then both jump): The V8 heap grows in chunks. Seeing repeated step-function increases in `process.memoryUsage().heapTotal` indicates the GC cannot free enough memory.
- **GC pause duration increasing**: Longer GC pauses mean more objects to scan. Visible in `--trace-gc` output or APM tools.
- **The "sawtooth that rises"**: Healthy GC shows a sawtooth pattern (allocate, collect, allocate, collect) at a stable baseline. A leak shows the same sawtooth but the baseline drifts upward.

### Diagnostic Tools

```bash
# Take a heap snapshot from a running process (via Chrome DevTools protocol)
kill -USR2 <pid>  # If using heapdump module

# Or using the V8 inspector
node --inspect app.js
# Then connect Chrome DevTools and take heap snapshots

# Compare two snapshots taken minutes apart:
# Objects that grow in count/size between snapshots are likely leaked
```

### Quick Check

```javascript
// Add this to your application for basic memory monitoring
setInterval(() => {
  const mem = process.memoryUsage();
  console.log(JSON.stringify({
    rss_mb: Math.round(mem.rss / 1048576),
    heap_used_mb: Math.round(mem.heapUsed / 1048576),
    heap_total_mb: Math.round(mem.heapTotal / 1048576),
    external_mb: Math.round(mem.external / 1048576),
  }));
}, 60000); // Log every minute
```

---

## How It Was Fixed

### Fix 1: Always Remove Event Listeners

```javascript
class ConnectionManager {
  handleRequest(req, res) {
    const onConfigChange = () => {
      res.setHeader('X-Config-Version', getConfigVersion());
    };

    this.eventBus.on('config-change', onConfigChange);

    // CRITICAL: Remove the listener when the response is done
    res.on('finish', () => {
      this.eventBus.removeListener('config-change', onConfigChange);
    });
  }
}

// Or use .once() if you only need the listener to fire one time
this.eventBus.once('config-change', onConfigChange);
```

### Fix 2: Bounded Caches with Eviction

```javascript
// Use an LRU cache with a maximum size
const LRU = require('lru-cache');

const cache = new LRU({
  max: 10000,          // Maximum 10,000 entries
  ttl: 1000 * 60 * 5,  // Entries expire after 5 minutes
  maxSize: 50 * 1024 * 1024,  // 50 MB max total size
  sizeCalculation: (value) => JSON.stringify(value).length,
});
```

### Fix 3: WeakRef and WeakMap for Caches

```javascript
// WeakMap keys are garbage collected when no other references exist
const sessionCache = new WeakMap();

function getSessionData(sessionObj) {
  if (sessionCache.has(sessionObj)) {
    return sessionCache.get(sessionObj);
  }
  const data = computeSessionData(sessionObj);
  sessionCache.set(sessionObj, data);
  // When sessionObj is garbage collected, the cache entry is too
  return data;
}
```

### Fix 4: Explicit Lifecycle Cleanup

```javascript
class Service {
  constructor() {
    this.intervals = [];
    this.listeners = [];
  }

  start() {
    const interval = setInterval(() => this.poll(), 5000);
    this.intervals.push(interval);

    const listener = (msg) => this.handleMessage(msg);
    messageBus.on('message', listener);
    this.listeners.push({ emitter: messageBus, event: 'message', fn: listener });
  }

  // CRITICAL: Implement cleanup
  stop() {
    this.intervals.forEach(clearInterval);
    this.intervals = [];
    this.listeners.forEach(({ emitter, event, fn }) => {
      emitter.removeListener(event, fn);
    });
    this.listeners = [];
  }
}
```

---

## Key Lessons

1. **Memory leaks in GC languages are reference leaks.** The GC works correctly -- the problem is that your code keeps references to objects it no longer needs.
2. **Every `addEventListener` / `on()` needs a corresponding `removeEventListener` / `off()`.** No exceptions.
3. **Unbounded data structures are time bombs.** Any `Map`, `Set`, array, or plain object at module scope that grows with traffic will eventually kill the process.
4. **Restarting is not a fix; it is a band-aid.** Daily restarts mask leaks and delay discovery. Find and fix the root cause.
5. **Heap snapshots are the gold standard for diagnosis.** Take two snapshots minutes apart, compare them, and look for object types growing in count.

---

## Detection Guide for Claude

### Red Flags

- **`eventEmitter.on()` or `addEventListener()` inside a request handler** or loop without a corresponding removal.
- **`setMaxListeners(0)` or `setMaxListeners(Infinity)`** -- this almost always means someone silenced a leak warning instead of fixing it.
- **Module-scope `{}`, `[]`, `new Map()`, or `new Set()`** that is written to during request handling with no eviction/size limit.
- **`setInterval` without a corresponding `clearInterval`** in the cleanup/destroy path.
- **Closures in long-lived objects** (middleware, singleton services) that capture request-scoped data (req, res, large buffers).
- **Missing `destroy()` / `close()` / `stop()` methods** on classes that set up timers, listeners, or streams.

### Pattern to Flag

```javascript
// Flag 1: Listener without cleanup
emitter.on('event', handler);  // Where is the .off() / .removeListener()?

// Flag 2: Unbounded module-scope storage
const data = {};  // or new Map(), [], new Set()
function handleRequest(req) {
  data[req.id] = something;  // Grows forever
}

// Flag 3: setInterval without cleanup path
setInterval(fn, N);  // Is clearInterval ever called?

// Flag 4: Silencing the warning
emitter.setMaxListeners(0);  // Almost certainly hiding a leak
```

### Suggested Fix

Recommend: (1) pair every `on()` with an `off()` in a cleanup path, (2) replace unbounded `{}` or `Map` with an LRU cache, (3) track all timers and clear them on shutdown, (4) implement a `destroy()` method on any class that sets up resources.

### Severity Assessment

- **Short-lived processes (Lambda, CLI tools):** Low -- the process dies before the leak matters.
- **Long-running servers with daily restarts:** Medium -- masked but still wasteful.
- **Long-running servers without restarts:** Critical -- will OOM eventually.
