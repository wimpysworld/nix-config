---
title: Prevent Insecure Deserialization
impact: CRITICAL
impactDescription: Remote code execution allowing attackers to run arbitrary code on the server
tags: security, deserialization, cwe-502
---

## Prevent Insecure Deserialization

Insecure deserialization occurs when untrusted data is used to abuse the logic of an application, inflict denial of service attacks, or execute arbitrary code. Objects can be serialized into strings and later loaded from strings, but deserialization of untrusted data can lead to remote code execution (RCE). Never deserialize data from untrusted sources. Use safer alternatives like JSON for data interchange.

---

### Language: Python

#### Pickle Deserialization

**Incorrect (using pickle with user input):**
```python
import pickle
from base64 import b64decode
from flask import Flask, request

app = Flask(__name__)

@app.route('/', methods=['GET'])
def index():
    user_obj = request.cookies.get('uuid')
    return "Hey there! {}!".format(pickle.loads(b64decode(user_obj)))
```

**Correct (use JSON or load from trusted file):**
```python
import pickle
import json

@app.route("/ok")
def ok():
    # Load from trusted local file
    data = pickle.load(open('./config/settings.dat', "rb"))

    # Or use JSON for untrusted data
    user_data = json.loads(request.data)
    return user_data
```

**References:**
- CWE-502: Deserialization of Untrusted Data
- [Python pickle Documentation](https://docs.python.org/3/library/pickle.html)

---

### Language: JavaScript / TypeScript

#### Object Deserialization

**Incorrect (using insecure deserialization libraries):**
```typescript
var node_serialize = require("node-serialize")

module.exports.handler = function (req, res) {
    var data = req.files.products.data.toString('utf8')
    node_serialize.unserialize(data)
}
```

**Correct (use JSON.parse for untrusted data):**
```javascript
module.exports.handler = function (req, res) {
    var data = req.body.toString('utf8')
    var parsed = JSON.parse(data)
    return parsed
}
```

**References:**
- CWE-502: Deserialization of Untrusted Data
- [OWASP Deserialization Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Deserialization_Cheat_Sheet.html)

---

### Language: Java

#### ObjectInputStream Deserialization

**Incorrect (using ObjectInputStream to deserialize untrusted data):**
```java
import java.io.InputStream;
import java.io.ObjectInputStream;

public class Deserializer {
    public Object deserializeObject(InputStream receivedData) throws Exception {
        ObjectInputStream in = new ObjectInputStream(receivedData);
        return in.readObject();
    }
}
```

**Correct (use JSON or implement input validation):**
```java
import com.fasterxml.jackson.databind.ObjectMapper;
import java.io.InputStream;

public class SafeDeserializer {
    public MyClass deserialize(InputStream data) throws Exception {
        ObjectMapper mapper = new ObjectMapper();
        return mapper.readValue(data, MyClass.class);
    }
}
```

**References:**
- CWE-502: Deserialization of Untrusted Data
- [OWASP Deserialization of Untrusted Data](https://www.owasp.org/index.php/Deserialization_of_untrusted_data)
- [Oracle Java Security Guidelines](https://www.oracle.com/java/technologies/javase/seccodeguide.html#8)

---

### Language: Ruby

#### Marshal/YAML Deserialization

**Incorrect (using Marshal.load or YAML.load with user input):**
```ruby
def bad_deserialization
    data = params['data']
    obj = Marshal.load(data)

    yaml_data = params['yaml']
    config = YAML.load(yaml_data)
end
```

**Correct (use safe options or trusted data):**
```ruby
def ok_deserialization
    # Use YAML.safe_load for untrusted data
    config = YAML.safe_load(params['yaml'])

    # Load from trusted file
    obj = YAML.load(File.read("config.yml"))

    # Use JSON for untrusted data
    data = JSON.parse(params['data'])
end
```

**References:**
- CWE-502: Deserialization of Untrusted Data
- [Ruby Security Advisory](https://groups.google.com/g/rubyonrails-security/c/61bkgvnSGTQ/m/nehwjA8tQ8EJ)

---

### Language: C#

#### BinaryFormatter Deserialization

**Incorrect (using BinaryFormatter which is inherently insecure):**
```csharp
using System.Runtime.Serialization.Formatters.Binary;

public class InsecureDeserialization {
    public void Deserialize(string data) {
        BinaryFormatter formatter = new BinaryFormatter();
        MemoryStream stream = new MemoryStream(Encoding.UTF8.GetBytes(data));
        object obj = formatter.Deserialize(stream);
    }
}
```

**Correct (use System.Text.Json or Newtonsoft with safe settings):**
```csharp
using System.Text.Json;

public class SafeDeserialization {
    public MyClass Deserialize(string json) {
        return JsonSerializer.Deserialize<MyClass>(json);
    }
}
```

**References:**
- CWE-502: Deserialization of Untrusted Data
- [Microsoft BinaryFormatter Security Guide](https://docs.microsoft.com/en-us/dotnet/standard/serialization/binaryformatter-security-guide)

---

### Language: PHP

#### unserialize() with User Input

**Incorrect (unserializing user-controlled data):**
```php
<?php
$data = $_GET["data"];
$object = unserialize($data);
```

**Correct (use JSON or hardcoded data):**
```php
<?php
// Use json_decode for untrusted data
$object = json_decode($_GET["data"], true);

// Or use unserialize only with hardcoded strings
$object = unserialize('O:1:"a":1:{s:5:"value";s:3:"100";}');
```

**References:**
- CWE-502: Deserialization of Untrusted Data
- [PHP unserialize() Documentation](https://www.php.net/manual/en/function.unserialize.php)
- [OWASP Insecure Deserialization](https://owasp.org/www-project-top-ten/2017/A8_2017-Insecure_Deserialization.html)

---

## General Prevention Guidelines

1. **Never deserialize untrusted data** - Treat all external data as potentially malicious
2. **Use JSON for data interchange** - JSON only returns primitive types (strings, arrays, objects, numbers, null)
3. **Implement integrity checks** - Use HMACs to sign serialized data to detect tampering
4. **Use allowlists for deserialization** - Only allow specific, known-safe classes to be deserialized
5. **Avoid native serialization formats** - pickle, Marshal, ObjectInputStream, BinaryFormatter are all dangerous
6. **Use safe YAML loaders** - Always use SafeLoader or safe_load with YAML libraries
7. **Monitor and log deserialization** - Alert on unexpected deserialization attempts
8. **Keep libraries updated** - Apply security patches promptly

**References:**
- CWE-502: Deserialization of Untrusted Data
- [OWASP Deserialization Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Deserialization_Cheat_Sheet.html)
- [OWASP Top 10 A08:2021 - Software and Data Integrity Failures](https://owasp.org/Top10/A08_2021-Software_and_Data_Integrity_Failures/)
