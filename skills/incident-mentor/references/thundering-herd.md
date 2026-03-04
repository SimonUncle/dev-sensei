# Thundering Herd / Cache Stampede

## Incident: Instagram, 2012

**Severity:** High | **Category:** Caching / Performance | **Impact:** Site-wide degradation and partial outages

---

## What Happened

Instagram experienced repeated performance degradation during peak traffic hours.
Their Django/PostgreSQL stack used Memcached heavily to keep page renders fast. The
problem was subtle: cached objects were created with identical TTL values (e.g., 300
seconds). When a popular cache key expired, hundreds or thousands of concurrent
requests would simultaneously discover the cache miss and all race to regenerate the
same value by querying PostgreSQL directly.

### Timeline

1. Cache key for a popular resource (e.g., user feed, explore page data) expires.
2. Within milliseconds, 500+ concurrent requests arrive for that same key.
3. All 500 requests see a cache miss and independently query the database.
4. PostgreSQL connection pool saturates; queries start queuing.
5. Latency spikes cascade: upstream services time out, load balancers retry, amplifying the storm.
6. Cache is eventually repopulated, but by then the damage is done -- slow responses, dropped requests, and elevated error rates for 30-60 seconds.
7. Pattern repeats every 5 minutes (the TTL) for every hot key.

### Scale of Impact

- Database CPU spikes from 20% to 100% in under 2 seconds on each stampede.
- P99 latency jumped from ~50ms to 5-10 seconds during stampede windows.
- Estimated millions of redundant database queries per day.

---

## Technical Root Cause

The core pattern is deceptively simple -- a cache-aside (lazy-loading) strategy with
no stampede protection:

```python
# THE PROBLEMATIC PATTERN
def get_user_feed(user_id):
    cache_key = f"feed:{user_id}"
    result = cache.get(cache_key)

    if result is None:
        # DANGER: Every concurrent request executes this block simultaneously
        result = db.query("SELECT * FROM posts WHERE user_id IN "
                          "(SELECT followee_id FROM follows WHERE follower_id = %s) "
                          "ORDER BY created_at DESC LIMIT 50", [user_id])
        cache.set(cache_key, result, ttl=300)  # Fixed TTL -- all keys expire in sync

    return result
```

The two compounding problems:

1. **No mutual exclusion on cache miss**: Every request that sees `None` independently hammers the database with the same expensive query.
2. **Synchronized expiration**: Using a fixed TTL (300s) means keys created around the same time all expire around the same time, creating periodic stampede waves.

---

## How It Was Detected

- Database monitoring dashboards showed CPU spikes with a perfectly periodic pattern (~5 minute intervals).
- Memcached hit-rate graphs showed sharp dips correlating exactly with DB spikes.
- Application-level tracing revealed hundreds of identical SQL queries executing within the same 100ms window.

---

## How It Was Fixed

### Fix 1: Mutex / Lock on Cache Miss

Only one request regenerates the cache; others wait or get a stale value.

```python
def get_user_feed(user_id):
    cache_key = f"feed:{user_id}"
    result = cache.get(cache_key)

    if result is None:
        lock_key = f"lock:{cache_key}"
        if cache.add(lock_key, "1", ttl=10):  # Atomic "add if not exists"
            try:
                result = db.query(FEED_QUERY, [user_id])
                cache.set(cache_key, result, ttl=300)
            finally:
                cache.delete(lock_key)
        else:
            # Another request is regenerating; wait briefly or return stale data
            time.sleep(0.05)
            result = cache.get(cache_key)  # Retry once
            if result is None:
                result = get_stale_fallback(cache_key)  # Serve slightly stale data

    return result
```

### Fix 2: TTL Jitter (Randomized Expiration)

Prevent synchronized expiration by adding a random offset to the TTL.

```python
import random

base_ttl = 300
jitter = random.randint(0, 60)  # Random offset of 0-60 seconds
cache.set(cache_key, result, ttl=base_ttl + jitter)
```

This spreads expirations across a 60-second window instead of all hitting at once.

### Fix 3: Early / Probabilistic Refresh

Refresh the cache before it actually expires. The closer a key is to expiration, the
higher the probability a request will proactively refresh it.

```python
def get_with_early_refresh(cache_key, ttl=300, beta=1.0):
    result, expiry_time = cache.get_with_expiry(cache_key)

    if result is not None:
        remaining = expiry_time - time.time()
        # XFetch algorithm: probabilistically refresh as expiry approaches
        if remaining > 0 and random.random() < math.exp(-remaining / (beta * ttl)):
            # Refresh in background; current request still uses cached value
            background_refresh(cache_key)

    return result
```

---

## Key Lessons

1. **Cache misses are a thundering herd trigger.** Any cache-aside pattern without stampede protection is a latent incident waiting for enough traffic.
2. **Fixed TTLs create periodic failure patterns.** Always add jitter.
3. **The database is your last line of defense, not your first.** Protect it with locks, queuing, or pre-warming.
4. **Stale data is usually better than no data.** Serving a value that is 5 seconds old is almost always preferable to a timeout.

---

## Detection Guide for Claude

When reviewing user code, flag the following patterns:

### Red Flags
- `cache.get()` followed by a database query on cache miss with **no locking or mutex**.
- `cache.set(key, value, ttl=FIXED_NUMBER)` with a hardcoded TTL and no jitter.
- Hot paths (API endpoints, feed generation, search) using cache-aside with no stampede protection.
- No distinction between "cache miss" and "cache not yet populated" -- both trigger full recomputation.

### What to Look For (Any Language)
```
# Pattern: unprotected cache-aside
result = cache.get(key)
if not result:
    result = expensive_query()     # <-- No lock, no dedup
    cache.set(key, result, ttl=N)  # <-- No jitter on TTL
```

### Suggested Fix Template
Recommend the user add: (1) a lock/mutex on cache regeneration, (2) TTL jitter of 10-20% of the base TTL, and (3) a stale-data fallback so requests never block indefinitely.

### Severity Assessment
- **Low traffic:** Minor -- stampedes are unlikely with few concurrent users.
- **Medium traffic (100+ RPS on a single key):** High risk -- recommend immediate fix.
- **High traffic (1000+ RPS):** Critical -- this will cause outages.
