# N+1 Query Problem

## Incident: GitHub and the Broader ORM Ecosystem

**Severity:** Medium-High | **Category:** Database / ORM | **Impact:** Page loads degrading from milliseconds to seconds

---

## What Happened

The N+1 query problem is one of the most common performance bugs in web applications.
GitHub publicly discussed battling N+1 queries in their Rails codebase as they scaled.
In 2012-2013, GitHub engineers wrote extensively about how lazy-loaded ActiveRecord
associations caused page render times to balloon as repositories grew. A repository
page that loaded fine with 10 contributors would grind to a halt with 500, because
each contributor triggered an individual SQL query.

This pattern affects every major ORM: Rails ActiveRecord, Django ORM, SQLAlchemy,
Sequelize, Prisma, Hibernate, and Entity Framework. It is not a bug in the ORM -- it
is a consequence of lazy loading, which defers query execution until data is accessed.

### Real-World Impact

- A GitHub repository page with 200 contributors: 1 query for the repo + 200 queries for contributor profiles = **201 SQL queries** for a single page load.
- A Django admin list page showing 100 orders with customer names: 1 query for orders + 100 queries for customers = **101 queries**, turning a 15ms page into a 3-second page.
- At scale, N+1 queries are the single most common cause of "the app is slow" complaints in ORM-based applications.

---

## Technical Root Cause

### The Pattern

```python
# Django ORM -- THE PROBLEMATIC PATTERN
def list_users_with_posts(request):
    users = User.objects.all()[:100]  # Query 1: SELECT * FROM users LIMIT 100

    result = []
    for user in users:
        # Query 2..101: SELECT * FROM posts WHERE user_id = <id>
        # Each iteration triggers a SEPARATE database query
        posts = user.posts.all()
        result.append({"user": user.name, "post_count": posts.count()})

    return JsonResponse(result)
```

### What the Database Actually Sees

```sql
-- Query 1 (the "1" in N+1)
SELECT id, name, email FROM users LIMIT 100;

-- Queries 2-101 (the "N" in N+1) -- one per user
SELECT id, title, body, user_id FROM posts WHERE user_id = 1;
SELECT id, title, body, user_id FROM posts WHERE user_id = 2;
SELECT id, title, body, user_id FROM posts WHERE user_id = 3;
-- ... 97 more identical queries with different user_id values
SELECT id, title, body, user_id FROM posts WHERE user_id = 100;
```

Each query is fast individually (1-2ms), but 101 sequential round trips to the
database add up: 101 x 2ms = ~200ms minimum, and much worse under load when
connection pool contention and network latency compound.

### The Deeper Problem: It Hides in Templates Too

```html
<!-- Rails ERB template -- N+1 hidden in the view layer -->
<% @posts.each do |post| %>
  <div>
    <h2><%= post.title %></h2>
    <!-- This innocent-looking call triggers a SQL query per iteration -->
    <p>By: <%= post.author.name %></p>
    <p>Category: <%= post.category.name %></p>  <!-- Another N queries! -->
  </div>
<% end %>
<!-- Total: 1 + N + N = 1 + 2N queries -->
```

---

## How It Was Detected

- **Query logging**: Rails `config.log_level = :debug` or Django `django.db.connection.queries` showing hundreds of near-identical queries.
- **APM tools**: New Relic, Datadog, or Scout showing a single endpoint making 100+ DB calls.
- **GitHub's Scientist gem**: Used to compare code paths and measure query counts.
- **Bullet gem (Rails)**: Automatically detects N+1 queries in development and warns developers.

### Quick Detection Query Log

If your query log for a single request looks like this, you have an N+1:
```
[2ms] SELECT * FROM users LIMIT 50
[1ms] SELECT * FROM posts WHERE user_id = 1
[1ms] SELECT * FROM posts WHERE user_id = 2
[1ms] SELECT * FROM posts WHERE user_id = 3
... (47 more)
```

---

## How It Was Fixed

### Fix 1: Eager Loading (Most Common Fix)

Load related data upfront in a single query or a small number of queries.

```python
# Django -- prefetch_related (separate query, joined in Python)
users = User.objects.prefetch_related('posts').all()[:100]
# Query 1: SELECT * FROM users LIMIT 100
# Query 2: SELECT * FROM posts WHERE user_id IN (1, 2, 3, ..., 100)
# Total: 2 queries instead of 101

# Django -- select_related (SQL JOIN, single query)
posts = Post.objects.select_related('author', 'category').all()[:100]
# Query 1: SELECT posts.*, users.*, categories.*
#          FROM posts
#          JOIN users ON posts.user_id = users.id
#          JOIN categories ON posts.category_id = categories.id
#          LIMIT 100
```

```ruby
# Rails ActiveRecord
users = User.includes(:posts).limit(100)      # Eager load with 2 queries
users = User.eager_load(:posts).limit(100)     # Eager load with JOIN
```

```typescript
// Prisma
const users = await prisma.user.findMany({
  take: 100,
  include: { posts: true }  // Eager load posts in a single query
});
```

### Fix 2: DataLoader Pattern (GraphQL / Batching)

For GraphQL APIs where the query structure is dynamic, Facebook's DataLoader batches
individual lookups into a single query per tick of the event loop.

```javascript
const DataLoader = require('dataloader');

const postLoader = new DataLoader(async (userIds) => {
  // Single query for ALL requested user IDs
  const posts = await db.query(
    'SELECT * FROM posts WHERE user_id = ANY($1)', [userIds]
  );
  // Group by user_id and return in same order as input
  const grouped = groupBy(posts, 'user_id');
  return userIds.map(id => grouped[id] || []);
});

// In resolver -- each call is batched automatically
const resolvers = {
  User: {
    posts: (user) => postLoader.load(user.id)
  }
};
```

### Fix 3: Aggregation at the Database Level

If you only need counts or summaries, push the work to the database.

```python
# Instead of loading all posts to count them:
from django.db.models import Count
users = User.objects.annotate(post_count=Count('posts')).all()[:100]
# Single query: SELECT users.*, COUNT(posts.id) FROM users LEFT JOIN posts ...
```

---

## Key Lessons

1. **ORMs trade query visibility for developer convenience.** Lazy loading is a feature, but it requires discipline to use correctly.
2. **Always check your query count per request.** A healthy endpoint makes 1-10 queries, not 100+.
3. **N+1 queries are O(N) in the worst dimension** -- they scale with your data, so they only get worse as you grow.
4. **Detection tools pay for themselves immediately.** Bullet (Rails), django-debug-toolbar (Django), or nplusone (Python) catch these in development before they reach production.

---

## Detection Guide for Claude

### Red Flags

- A **loop** iterating over ORM objects that **accesses a related model** inside the loop body.
- ORM queries without `.include()`, `.prefetch_related()`, `.select_related()`, `.eager_load()`, or `.includes()` when related data is used later.
- GraphQL resolvers that make individual database calls without a DataLoader or batching mechanism.
- Template files accessing `object.relation.field` inside a loop.

### Pattern to Flag (Any Language)

```
# Pseudocode pattern -- always flag this
items = ORM.findAll(Model)
for item in items:
    related = item.relatedModel  # <-- Triggers lazy load = 1 query per iteration
```

### Suggested Fix

Recommend the user add eager loading appropriate to their ORM, or restructure the query to use a JOIN or subquery. If they are using GraphQL, recommend the DataLoader pattern.

### Severity Assessment

- **N < 10:** Low -- barely noticeable, but fix it before it grows.
- **N = 10-100:** Medium -- noticeable latency, especially under load.
- **N > 100:** High -- this is actively degrading user experience and wasting database resources.
