---
title: Avoid Hardcoded Secrets
impact: CRITICAL
impactDescription: Credential exposure and unauthorized access
tags: security, secrets, credentials, api-keys, cwe-798, owasp-a07
---

## Avoid Hardcoded Secrets

Hardcoded credentials, API keys, tokens, and other secrets in source code pose a critical security risk. When secrets are committed to version control, they can be exposed to unauthorized parties through repository access, leaked in public repositories or through data breaches, difficult to rotate without code changes and redeployment, and discovered by automated secret scanning tools used by attackers. Always use environment variables, secret managers, or secure vaults to provide credentials at runtime.

### AWS Credentials

**Incorrect (Python - hardcoded AWS credentials):**

```python
import boto3

client("s3", aws_secret_access_key="jWnyxxxxxxxxxxxxxxxxX7ZQxxxxxxxxxxxxxxxx")

s3 = boto3.resource(
    "s3",
    aws_access_key_id="AKIAxxxxxxxxxxxxxxxx",
    aws_secret_access_key="jWnyxxxxxxxxxxxxxxxxX7ZQxxxxxxxxxxxxxxxx",
    region_name="us-east-1",
)
```

**Correct (Python - AWS credentials from environment):**

```python
import boto3
import os

key = os.environ.get("ACCESS_KEY_ID")
secret = os.environ.get("SECRET_ACCESS_KEY")
s3 = boto3.resource(
    "s3",
    aws_access_key_id=key,
    aws_secret_access_key=secret,
    region_name="us-east-1",
)
```

### API Keys and Tokens

**Incorrect (JavaScript - hardcoded JWT secret):**

```javascript
const jsonwt = require('jsonwebtoken')

function signToken() {
  const payload = {foo: 'bar'}
  const token = jsonwt.sign(payload, 'my-secret-key')
  return token
}
```

**Correct (JavaScript - JWT secret from environment):**

```javascript
const jsonwt = require('jsonwebtoken')

function signToken() {
  const payload = {foo: 'bar'}
  const secret = process.env.JWT_SECRET
  const token = jsonwt.sign(payload, secret)
  return token
}
```

**Incorrect (JavaScript - hardcoded express-jwt secret):**

```javascript
var jwt = require('express-jwt');

app.get('/protected', jwt({ secret: 'shhhhhhared-secret' }), function(req, res) {
    if (!req.user.admin) return res.sendStatus(401);
    res.sendStatus(200);
});
```

**Correct (JavaScript - express-jwt secret from environment):**

```javascript
var jwt = require('express-jwt');

app.get('/protected', jwt({ secret: process.env.JWT_SECRET }), function(req, res) {
    if (!req.user.admin) return res.sendStatus(401);
    res.sendStatus(200);
});
```

### Hardcoded Passwords

**Incorrect (Python Flask - hardcoded SECRET_KEY):**

```python
import flask
app = flask.Flask(__name__)

app.config["SECRET_KEY"] = '_5#y2L"F4Q8z\n\xec]/'
```

**Correct (Python Flask - SECRET_KEY from environment):**

```python
import os
import flask
app = flask.Flask(__name__)

app.config["SECRET_KEY"] = os.environ["SECRET_KEY"]
```

**Incorrect (Python - empty password string):**

```python
from models import UserProfile

def set_user_password(user_profile: UserProfile) -> None:
    password = ""
    user_profile.set_password(password)
    user_profile.save()
```

**Correct (Python - password from secure source):**

```python
from models import UserProfile

def set_user_password(user_profile: UserProfile, password: str) -> None:
    user_profile.set_password(password)
    user_profile.save()
```

### Third-Party Service Tokens

**Incorrect (JavaScript - hardcoded Stripe token):**

```javascript
const stripe = require('stripe');

const client = stripe('sk_test_20cbqx6v2hpftsbq203r36yqccazez');
```

**Correct (JavaScript - Stripe token from environment):**

```javascript
const stripe = require('stripe');

const client = stripe(process.env.STRIPE_SECRET_KEY);
```

**Incorrect (Python - hardcoded GitHub token):**

```python
import requests

headers = {"Authorization": "token ghp_emmtytndiqky5a98w0s98w36fakekey"}
response = requests.get("https://api.github.com/user", headers=headers)
```

**Correct (Python - GitHub token from environment):**

```python
import os
import requests

headers = {"Authorization": f"token {os.environ['GITHUB_TOKEN']}"}
response = requests.get("https://api.github.com/user", headers=headers)
```
