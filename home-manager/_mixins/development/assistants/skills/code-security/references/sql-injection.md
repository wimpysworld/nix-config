---
title: Prevent SQL Injection
impact: CRITICAL
impactDescription: Attackers can read, modify, or delete database data
tags: security, sql, database, cwe-89, owasp-a03
---

## Prevent SQL Injection

SQL injection allows attackers to manipulate database queries by injecting malicious SQL through user input. Never concatenate user input into SQL queries - always use parameterized queries or prepared statements.

**Vulnerable patterns:** String concatenation (`+`), format strings (`.format()`, `%`, f-strings, `String.Format()`), template literals with variables.

---

### Python (psycopg2)

**Incorrect (string concatenation):**

```python
import psycopg2

def get_user(user_input):
    conn = psycopg2.connect("dbname=test")
    cur = conn.cursor()
    query = "SELECT * FROM users WHERE name = '" + user_input + "'"
    cur.execute(query)
```

**Incorrect (format string):**

```python
def get_user(user_input):
    cur.execute("SELECT * FROM users WHERE id = {}".format(user_input))
```

**Incorrect (f-string):**

```python
def get_user(user_input):
    cur.execute(f"SELECT * FROM users WHERE id = {user_input}")
```

**Correct (parameterized query):**

```python
def get_user(user_input):
    conn = psycopg2.connect("dbname=test")
    cur = conn.cursor()
    cur.execute("SELECT * FROM users WHERE name = %s", [user_input])
```

---

### JavaScript/Node.js (pg)

**Incorrect (template literal with variable):**

```javascript
const { Pool } = require('pg')
const pool = new Pool()

async function getUser(userId) {
  const sql = `SELECT * FROM users WHERE id = ${userId}`
  const { rows } = await pool.query(sql)
  return rows
}
```

**Incorrect (string concatenation):**

```javascript
async function getUser(userId) {
  const sql = "SELECT * FROM users WHERE id = " + userId
  const { rows } = await pool.query(sql)
  return rows
}
```

**Correct (parameterized query):**

```javascript
async function getUser(userId) {
  const sql = 'SELECT * FROM users WHERE id = $1'
  const { rows } = await pool.query(sql, [userId])
  return rows
}
```

---

### Java (JDBC)

**Incorrect (string concatenation with Statement):**

```java
public ResultSet getUser(String input) throws SQLException {
    Statement stmt = connection.createStatement();
    String sql = "SELECT * FROM users WHERE name = '" + input + "'";
    return stmt.executeQuery(sql);
}
```

**Incorrect (String.format):**

```java
public ResultSet getUser(String input) throws SQLException {
    Statement stmt = connection.createStatement();
    return stmt.executeQuery(String.format("SELECT * FROM users WHERE name = '%s'", input));
}
```

**Correct (PreparedStatement with parameters):**

```java
public ResultSet getUser(String input) throws SQLException {
    PreparedStatement pstmt = connection.prepareStatement(
        "SELECT * FROM users WHERE name = ?");
    pstmt.setString(1, input);
    return pstmt.executeQuery();
}
```

---

### Go (database/sql)

**Incorrect (string concatenation):**

```go
func getUser(db *sql.DB, userInput string) {
    query := "SELECT * FROM users WHERE name = '" + userInput + "'"
    db.Query(query)
}
```

**Incorrect (fmt.Sprintf):**

```go
func getUser(db *sql.DB, email string) {
    query := fmt.Sprintf("SELECT * FROM users WHERE email = '%s'", email)
    db.Query(query)
}
```

**Correct (parameterized query):**

```go
func getUser(db *sql.DB, userInput string) {
    db.Query("SELECT * FROM users WHERE name = $1", userInput)
}
```

---

### Ruby (pg gem)

**Incorrect (string concatenation):**

```ruby
def get_user(user_input)
  conn = PG.connect(dbname: 'test')
  query = "SELECT * FROM users WHERE name = '" + user_input + "'"
  conn.exec(query)
end
```

**Incorrect (string interpolation):**

```ruby
def get_user(user_input)
  conn = PG.connect(dbname: 'test')
  conn.exec("SELECT * FROM users WHERE name = '#{user_input}'")
end
```

**Correct (parameterized query):**

```ruby
def get_user(user_input)
  conn = PG.connect(dbname: 'test')
  conn.exec_params('SELECT * FROM users WHERE name = $1', [user_input])
end
```

---

### C# (SqlCommand)

**Incorrect (String.Format):**

```csharp
public void GetUser(string userInput)
{
    SqlCommand command = connection.CreateCommand();
    command.CommandText = String.Format(
        "SELECT * FROM users WHERE name = '{0}'", userInput);
}
```

**Incorrect (string concatenation):**

```csharp
public void GetUser(string userInput)
{
    SqlCommand command = new SqlCommand(
        "SELECT * FROM users WHERE name = '" + userInput + "'");
}
```

**Correct (SqlParameter):**

```csharp
public void GetUser(string userInput)
{
    string sql = "SELECT * FROM users WHERE name = @Name";
    SqlCommand command = new SqlCommand(sql);
    command.Parameters.Add("@Name", SqlDbType.NVarChar);
    command.Parameters["@Name"].Value = userInput;
}
```

---

### Key Prevention Rules

1. **Never concatenate user input** into SQL strings
2. **Use parameterized queries** with placeholders (`?`, `$1`, `@param`, `%s`)
3. **Use prepared statements** which separate SQL logic from data
4. **Use ORM methods** that handle parameterization automatically
5. **Validate and sanitize** input as defense in depth

**References:**
- [CWE-89: SQL Injection](https://cwe.mitre.org/data/definitions/89.html)
- [OWASP SQL Injection Prevention](https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html)
- [OWASP A03:2021 Injection](https://owasp.org/Top10/A03_2021-Injection/)
