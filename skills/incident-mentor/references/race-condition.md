# Race Condition: Read-Modify-Write

## Incident: Financial System Double-Spend (Composite of Real Cases)

**Severity:** Critical | **Category:** Concurrency / Data Integrity | **Impact:** Incorrect financial balances -- money created or destroyed

---

## What Happened

This is a composite of real incidents that have occurred at fintech companies, payment
processors, and e-commerce platforms. The specific details are drawn from public
post-mortems by companies including Flexcoin (2014, which lost 896 BTC to this exact
pattern and shut down), various payment processors, and documented incidents across
the fintech industry.

The core scenario: a user with a $500 balance submits two $400 withdrawal requests
nearly simultaneously -- by double-clicking a button, by scripting parallel API calls,
or through a mobile app retry on a flaky network. Both requests read the balance as
$500, both determine the withdrawal is valid, and both deduct $400. The user receives
$800 while only $400 is deducted from their account. Alternatively, depending on the
write order, the balance ends up at $100 (only one deduction applied) instead of the
correct -$300 (which should have been rejected).

### Real-World Variants

- **Flexcoin (March 2014)**: Attackers exploited a race condition in the Bitcoin exchange's hot wallet withdrawal system. By submitting thousands of simultaneous withdrawal requests, they extracted 896 BTC (~$600,000 at the time). Flexcoin shut down permanently.
- **E-commerce inventory**: Two customers "buy the last item" simultaneously. Both orders succeed. One customer gets an apology email.
- **Coupon/promo code abuse**: A single-use code is checked and consumed in separate non-atomic steps. Concurrent requests all pass the check before any consume the code.
- **Ticket booking**: Two users book the same seat on the same flight. Both get confirmation emails.

---

## Technical Root Cause

The fundamental problem is a **read-modify-write cycle without atomicity**. The code
reads a value, makes a decision based on it, and writes a new value -- but between the
read and the write, another concurrent operation can change the underlying data.

### The Problematic Pattern

```python
# DANGEROUS: Read-modify-write without any concurrency protection
async def withdraw(user_id, amount):
    # Step 1: READ current balance
    user = await db.query("SELECT balance FROM accounts WHERE id = $1", [user_id])
    balance = user.balance

    # Step 2: DECIDE based on stale data
    if balance < amount:
        raise InsufficientFundsError()

    # Step 3: WRITE new balance
    # By now, another concurrent request may have already changed the balance!
    new_balance = balance - amount
    await db.query("UPDATE accounts SET balance = $1 WHERE id = $2",
                   [new_balance, user_id])

    return {"new_balance": new_balance}
```

### Race Condition Timeline

```
Time    Request A (withdraw $400)          Request B (withdraw $400)
----    -------------------------          -------------------------
T1      SELECT balance → $500
T2                                         SELECT balance → $500
T3      Check: 500 >= 400? Yes
T4                                         Check: 500 >= 400? Yes
T5      UPDATE balance = 500 - 400 = $100
T6                                         UPDATE balance = 500 - 400 = $100
                                           (overwrites A's write!)
Result: User withdrew $800, balance is $100 instead of -$300.
        $400 has been created from nothing.
```

This is called a **lost update** -- Request B's write is based on stale data and
overwrites Request A's write without incorporating it.

---

## How It Was Detected

- **Accounting reconciliation failures**: End-of-day balance totals did not match the sum of transactions. Money appeared from nowhere.
- **Negative balance alerts**: Users had negative balances that should have been prevented by the balance check.
- **Audit log analysis**: Two successful withdrawal records for the same user within milliseconds, both showing the same "previous balance."
- **Penetration testing**: Security teams deliberately sent concurrent requests and observed the race.

---

## How It Was Fixed

### Fix 1: Database Transaction with Proper Isolation Level

Wrap the read-modify-write in a SERIALIZABLE transaction.

```python
async def withdraw(user_id, amount):
    async with db.transaction(isolation_level='SERIALIZABLE'):
        user = await db.query(
            "SELECT balance FROM accounts WHERE id = $1", [user_id]
        )
        if user.balance < amount:
            raise InsufficientFundsError()

        await db.query(
            "UPDATE accounts SET balance = balance - $1 WHERE id = $2",
            [amount, user_id]
        )
    # If another transaction conflicts, the DB will abort one and it can be retried
```

Note: SERIALIZABLE has a performance cost. For most cases, the next two approaches
are preferred.

### Fix 2: Pessimistic Locking (SELECT FOR UPDATE)

Lock the row when reading so no other transaction can modify it until we are done.

```python
async def withdraw(user_id, amount):
    async with db.transaction():
        # SELECT FOR UPDATE acquires a row-level lock
        user = await db.query(
            "SELECT balance FROM accounts WHERE id = $1 FOR UPDATE", [user_id]
        )
        if user.balance < amount:
            raise InsufficientFundsError()

        await db.query(
            "UPDATE accounts SET balance = balance - $1 WHERE id = $2",
            [amount, user_id]
        )
    # Lock is released when transaction commits
    # Request B will block at SELECT FOR UPDATE until Request A commits
```

### Fix 3: Optimistic Locking (Version Column)

Add a version column; the UPDATE only succeeds if the version has not changed.

```python
async def withdraw(user_id, amount):
    user = await db.query(
        "SELECT balance, version FROM accounts WHERE id = $1", [user_id]
    )
    if user.balance < amount:
        raise InsufficientFundsError()

    result = await db.query(
        "UPDATE accounts SET balance = balance - $1, version = version + 1 "
        "WHERE id = $2 AND version = $3",
        [amount, user_id, user.version]
    )

    if result.rows_affected == 0:
        # Another transaction modified the row -- retry or fail
        raise ConflictError("Balance was modified concurrently, please retry")
```

### Fix 4: Atomic UPDATE with Condition (Simplest and Often Best)

Push the entire check-and-modify into a single atomic SQL statement.

```python
async def withdraw(user_id, amount):
    result = await db.query(
        "UPDATE accounts SET balance = balance - $1 "
        "WHERE id = $2 AND balance >= $1 "
        "RETURNING balance",
        [amount, user_id]
    )
    if result.rows_affected == 0:
        raise InsufficientFundsError()

    return {"new_balance": result[0].balance}
```

This is the gold standard for simple cases: no separate read, no race window.

---

## Key Lessons

1. **If you read and then write based on what you read, you have a potential race condition.** This is true in databases, in memory, in files, and in distributed systems.
2. **The check-then-act pattern is fundamentally broken without atomicity.** The check and the act must be a single indivisible operation.
3. **Low traffic hides race conditions.** They manifest probabilistically -- the more concurrent requests, the more likely the race triggers. Just because it "works in testing" does not mean it is safe.
4. **Financial operations demand the strongest guarantees.** Use pessimistic locking or atomic updates for anything involving money, inventory, or quotas.
5. **Idempotency keys prevent duplicate operations.** For API endpoints, require a client-generated idempotency key and reject duplicate submissions.

---

## Detection Guide for Claude

### Red Flags

- **Separate SELECT then UPDATE** on the same row where the UPDATE depends on the SELECT result, without a transaction or lock.
- **Balance/inventory/counter checks** done in application code rather than in the database (e.g., `if balance >= amount` in Python/JS, then a separate `UPDATE`).
- **No transaction wrapping** around read-modify-write sequences.
- **Missing `FOR UPDATE`** on SELECT queries in transactional code that modifies the selected data.
- **Shared mutable state in async code** (e.g., a module-level variable modified by concurrent request handlers without a mutex).

### Pattern to Flag (Any Language)

```
# ALWAYS flag this pattern:
value = db.read(key)
if value meets condition:
    db.write(key, new_value_based_on_value)

# Also flag in-memory variants:
counter = shared_state.get('counter')
shared_state.set('counter', counter + 1)  # Lost update in concurrent access
```

### Suggested Fix

For database operations: recommend atomic conditional UPDATE (`UPDATE ... WHERE balance >= $amount`), or `SELECT ... FOR UPDATE` within a transaction. For in-memory state: recommend a mutex, atomic operations, or moving the logic into the database. For API endpoints handling financial operations: recommend idempotency keys.

### Severity Assessment

- **Read-only data or non-critical counters:** Low.
- **Inventory, quotas, rate limits:** Medium-High.
- **Financial balances, payments, transfers:** Critical -- this is a money-losing bug.
