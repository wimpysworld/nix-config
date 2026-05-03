---
title: Prevent Prototype Pollution
impact: HIGH
impactDescription: Attackers can modify object prototypes to inject malicious properties
tags: security, prototype-pollution, cwe-915
---

## Prevent Prototype Pollution

Prototype pollution is a vulnerability that occurs when an attacker can modify the prototype of a base object, such as `Object.prototype` in JavaScript. This can create attributes that exist on every object or replace critical attributes with malicious ones.

**Mitigations:** Freeze prototypes with `Object.freeze(Object.prototype)`, use `Object.create(null)`, block `__proto__` and `constructor` keys, or use `Map` instead of objects.

**Incorrect (JavaScript - dynamic property assignment from user input):**

```javascript
app.get('/test/:id', (req, res) => {
    let id = req.params.id;
    let items = req.session.todos[id];
    if (!items) {
        items = req.session.todos[id] = {};
    }
    items[req.query.name] = req.query.text;
    res.end(200);
});
```

**Correct (JavaScript - validate against dangerous keys):**

```javascript
app.post('/test/:id', (req, res) => {
    let id = req.params.id;
    if (id !== 'constructor' && id !== '__proto__') {
        let items = req.session.todos[id];
        if (!items) {
            items = req.session.todos[id] = {};
        }
        items[req.query.name] = req.query.text;
    }
    res.end(200);
});
```

**Incorrect (JavaScript - nested property assignment in loop):**

```javascript
function setNestedValue(obj, props, value) {
  props = props.split('.');
  var lastProp = props.pop();
  while ((thisProp = props.shift())) {
    if (typeof obj[thisProp] == 'undefined') {
      obj[thisProp] = {};
    }
    obj = obj[thisProp];
  }
  obj[lastProp] = value;
}
```

**Correct (JavaScript - use numeric index or Map):**

```javascript
function safeIteration(name) {
  let config = this.config;
  name = name.split('.');
  for (let i = 0; i < name.length; i++) {
    config = config[i];
  }
  return this;
}
```

**Incorrect (JavaScript - Object.assign with user input):**

```javascript
function controller(req, res) {
    const defaultData = {foo: true}
    let data = Object.assign(defaultData, req.body)
    doSmthWith(data)
}
```

**Correct (JavaScript - use trusted data sources):**

```javascript
function controller(req, res) {
    const defaultData = {foo: {bar: true}}
    let data = Object.assign(defaultData, {foo: getTrustedFoo()})
    doSmthWith(data)
}
```

**References:**
- CWE-915: Improperly Controlled Modification of Dynamically-Determined Object Attributes
- [OWASP Mass Assignment Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Mass_Assignment_Cheat_Sheet.html)
