---
title: Prevent XML External Entity (XXE) Injection
impact: CRITICAL
impactDescription: File disclosure, SSRF, denial of service
tags: security, xxe, cwe-611
---

## Prevent XML External Entity (XXE) Injection

XXE occurs when XML input containing a reference to an external entity is processed by a weakly configured XML parser. Attackers can access local files, perform SSRF, or cause DoS.

---

### Language: Java

#### DocumentBuilderFactory - Disallow DOCTYPE Declaration

**Incorrect (vulnerable to XXE):**
```java
class BadDocumentBuilderFactory {
    public void parseXml() throws ParserConfigurationException {
        DocumentBuilderFactory dbf = DocumentBuilderFactory.newInstance();
        dbf.newDocumentBuilder();
    }
}
```

**Correct (XXE disabled):**
```java
class GoodDocumentBuilderFactory {
    public void parseXml() throws ParserConfigurationException {
        DocumentBuilderFactory dbf = DocumentBuilderFactory.newInstance();
        dbf.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true);
        dbf.newDocumentBuilder();
    }
}
```

**References:**
- CWE-611: Improper Restriction of XML External Entity Reference
- [OWASP XXE Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/XML_External_Entity_Prevention_Cheat_Sheet.html)
- [Semgrep Java XXE Cheat Sheet](https://semgrep.dev/docs/cheat-sheets/java-xxe/)

---

### Language: Python

#### Native xml Library Usage

**Incorrect (vulnerable to XXE):**
```python
def parse_xml():
    from xml.etree import ElementTree
    tree = ElementTree.parse('data.xml')
    root = tree.getroot()
```

**Correct (safe usage):**
```python
def parse_xml():
    from defusedxml.etree import ElementTree
    tree = ElementTree.parse('data.xml')
    root = tree.getroot()
```

**References:**
- CWE-611: Improper Restriction of XML External Entity Reference
- [Python xml Documentation](https://docs.python.org/3/library/xml.html)
- [defusedxml on GitHub](https://github.com/tiran/defusedxml)

---

### Language: JavaScript

#### libxmljs - noent Option Enabled

**Incorrect (vulnerable to XXE):**
```javascript
var libxmljs = require("libxmljs");

module.exports.parseXml = function(req, res) {
    libxmljs.parseXml(req.body, { noent: true, noblanks: true });
}
```

**Correct (XXE disabled):**
```javascript
var libxmljs = require("libxmljs");

module.exports.parseXml = function(req, res) {
    libxmljs.parseXml(req.body, { noent: false, noblanks: true });
}
```

**References:**
- CWE-611: Improper Restriction of XML External Entity Reference
- [OWASP XXE Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/XML_External_Entity_Prevention_Cheat_Sheet.html)

---

### Language: C#

#### XmlReaderSettings with DtdProcessing.Parse

**Incorrect (vulnerable to XXE):**
```csharp
public void ParseXml(string input) {
    XmlReaderSettings rs = new XmlReaderSettings();
    rs.DtdProcessing = DtdProcessing.Parse;
    XmlReader myReader = XmlReader.Create(new StringReader(input), rs);

    while (myReader.Read()) {
        Console.WriteLine(myReader.Value);
    }
}
```

**Correct (XXE disabled):**
```csharp
public void ParseXml(string input) {
    XmlReaderSettings rs = new XmlReaderSettings();
    rs.DtdProcessing = DtdProcessing.Prohibit;
    XmlReader myReader = XmlReader.Create(new StringReader(input), rs);

    while (myReader.Read()) {
        Console.WriteLine(myReader.Value);
    }
}
```

**References:**
- CWE-611: Improper Restriction of XML External Entity Reference
- [XXE and .NET](https://www.jardinesoftware.net/2016/05/26/xxe-and-net/)

---

### Language: Go

#### libxml2 - External Entities Enabled

**Incorrect (vulnerable to XXE):**
```go
import (
    "fmt"
    "github.com/lestrrat-go/libxml2/parser"
)

func parseXml() {
    const s = `<!DOCTYPE d [<!ENTITY e SYSTEM "file:///etc/passwd">]><t>&e;</t>`
    p := parser.New(parser.XMLParseNoEnt)
    doc, err := p.ParseString(s)
    if err != nil {
        fmt.Println(err)
        return
    }
    fmt.Println(doc)
}
```

**Correct (XXE disabled):**
```go
import (
    "fmt"
    "github.com/lestrrat-go/libxml2/parser"
)

func parseXml() {
    const s = `<!DOCTYPE d [<!ENTITY e SYSTEM "file:///etc/passwd">]><t>&e;</t>`
    p := parser.New()
    doc, err := p.ParseString(s)
    if err != nil {
        fmt.Println(err)
        return
    }
    fmt.Println(doc)
}
```

**References:**
- CWE-611: Improper Restriction of XML External Entity Reference
- [OWASP XXE Processing](https://owasp.org/www-community/vulnerabilities/XML_External_Entity_(XXE)_Processing)
