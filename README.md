
# funcster

This library contains utilities for serializing and deserializing functions. It provides recursive traversal to discover nested functions and serialized functions, which is particularly useful for embedding functions in JSON objects.

## Function reference

### serialize(function, [marker])

```js
serialize(function() { return "Hello world!" });
// -> { __js_function: 'function() { return "Hello world!" }' }
```

----

### deepSerialize(root, [marker])

```js
lib = {
  moduleA: {
    functions: {
      helloWorld: function() { return "Hello world!" }
    }
  },
  moduleB: {
    functions: {
      goodbyeWorld: function() { return "Goodbye world!" }
    }
  },
};

funcster.deepSerialize(lib);

// -> {
//      moduleA: {
//        functions: {
//          helloWorld: { __js_function: 'function() { return "Hello world!" }' }
//        }
//      },
//      moduleB: {
//        functions: {
//          goodbyeWorld: { __js_function: 'function() { return "Goodbye world!" }' }
//        }
//      },
//    }
```

----

### deepDeserialize(root, [marker, [moduleOpts]])

```js
serializedLib = {
  moduleA: {
    functions: {
      helloWorld: { __js_function: 'function() { return "Hello world!" }' }
    }
  },
  moduleB: {
    functions: {
      goodbyeWorld: { __js_function: 'function() { return "Goodbye world!" }' }
    }
  },
};

deserializedLib = funcster.deepDeserialize(serializedLib);
deserializedLib.moduleA.functions.helloWorld(); // -> Hello world!
deserializedLib.moduleB.functions.goodbyeWorld(); // -> Hello world!
```