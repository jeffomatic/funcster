_ = require('underscore')
should = require('should')
testHelper = require('./test_helper')
funcster = require('../lib/funcster')

describe 'funcster module', () ->

  describe 'serialize()', () ->

    before () ->
      @testFunc = (arg) -> "Hello #{arg}!"
      @serializedTestFunc = funcster.serialize(@testFunc)

    it 'should wrap a function in an object', () ->
      _.keys(@serializedTestFunc).should.eql [ '__js_function' ]

    it 'should serialize the function to a string', () ->
      @serializedTestFunc.__js_function.should.eql @testFunc.toString()

    it 'should allow for custom serialization markers', () ->
      serialzed = funcster.serialize(@testFunc, 'CUSTOM_MARKER')
      _.keys(serialzed).should.eql [ 'CUSTOM_MARKER' ]

  describe 'deepSerialize()', () ->

    before () ->
      @original =
        arr: [
          (arg) -> "Hello #{arg}!"
          'hello!'
          1
          (arg) -> "Goodbye #{arg}!"
          {
            foo: 'bar'
            foobar: (arg) -> "FOOBAR: #{arg}"
          }
        ]
        obj:
          a: [
            {
              b: {
                c: (arg) -> "Super deep! #{arg}"
              }
            }
          ]
          z: 'just a string!'
      @serialized = funcster.deepSerialize(@original)

    it 'should serialize deeply nested functions', () ->
      @serialized.arr[0].__js_function.should.eql @original.arr[0].toString()
      @serialized.arr[3].__js_function.should.eql @original.arr[3].toString()
      @serialized.arr[4].foobar.__js_function.should.eql @original.arr[4].foobar.toString()
      @serialized.obj.a[0].b.c.__js_function.should.eql @original.obj.a[0].b.c.toString()

    it 'should retain non-function values', () ->
      @serialized.arr[1].should.eql 'hello!'
      @serialized.arr[2].should.eql 1
      @serialized.arr[4].foo.should.eql 'bar'
      @serialized.obj.z.should.eql 'just a string!'

  describe '_deepSelectSerializations()', () ->

    before () ->
      @selected = funcster._deepSelectSerializations(@serialized)

    it 'should collect all serialized functions', () ->
      @selected.length.should.eql 4

    it 'should set paths correctly', () ->
      @selected[0].path.should.eql [ 'arr', '0' ]
      @selected[1].path.should.eql [ 'arr', '3' ]
      @selected[2].path.should.eql [ 'arr', '4', 'foobar' ]
      @selected[3].path.should.eql [ 'obj', 'a', '0', 'b', 'c' ]

  describe '_generateModuleScript()', () ->

    it 'should encode functions into a text script', () ->
      functions =
        'func_a': 'function(arg) { return arg; }'
        'func_b': 'function(arg) { return [ arg ]; }'

      script = funcster._generateModuleScript(functions)
      script.should.eql 'module.exports=(function(module,exports){return{func_a: function(arg) { return arg; },func_b: function(arg) { return [ arg ]; }};})();'

  describe '_generateModule()', () ->

    it 'should export objects', () ->
      func = (arg) -> "Hello #{arg}!"
      script = "module.exports = { foo: #{func.toString()} }"
      moduleObj = funcster._generateModule(script)
      (moduleObj?).should.eql true
      (moduleObj.foo?).should.eql true
      moduleObj.foo('world').should.eql 'Hello world!'

    it 'should not include typical node.js globals by default', () ->
      objects = [ 'global', 'process', 'require', 'setTimeout', 'clearTimeout',
        'setInterval', 'clearInterval', 'console', 'Buffer', '__filename',
        '__dirname' ]
      functions = []
      functions.push "#{obj}: function() { #{obj}; }" for obj in objects
      script = 'module.exports = {' + functions.join(',') + '}'
      moduleObj = funcster._generateModule(script)
      (() -> moduleObj[obj]()).should.throw /is not defined/ for obj in objects

    it 'should have falsy values for modules and exports when using standard template', () ->
      objects = [ 'module', 'exports' ]
      functions = {}
      functions[obj] = "function() { return !#{obj}; }" for obj in objects
      script = funcster._generateModuleScript(functions)
      moduleObj = funcster._generateModule(script)
      moduleObj[obj]().should.eql true for obj in objects

    it 'should define standard global values', () ->
      objects = [ 'Object', 'Array', 'String', 'Date', 'Function' ]
      functions = {}
      functions[obj] = "function() { return !!#{obj}; }" for obj in objects
      script = funcster._generateModuleScript(functions)
      moduleObj = funcster._generateModule(script)
      moduleObj[obj]().should.eql true for obj in objects

    it 'instanceof operator fails by default', () ->
      objects = [ 'Object', 'Array', 'String', 'Date', 'Function' ]
      functions = {}
      functions[obj] = "function(arg) { return arg instanceof #{obj}; }" for obj in objects
      script = funcster._generateModuleScript(functions)
      moduleObj = funcster._generateModule(script)
      moduleObj.Object({}).should.eql false
      moduleObj.Array([]).should.eql false
      moduleObj.String(new String).should.eql false
      moduleObj.Function(() ->).should.eql false
      moduleObj.Date(new Date).should.eql false

    it 'instanceof operator succeeds with global injection', () ->
      objects = [ 'Object', 'Array', 'String', 'Date', 'Function' ]
      functions = {}
      functions[obj] = "function(arg) { return arg instanceof #{obj}; }" for obj in objects
      script = funcster._generateModuleScript(functions)
      moduleObj = funcster._generateModule(script,
        globals:
          Object: Object
          Array: Array
          String: String
          Function: Function
          Date: Date
      )
      moduleObj.Object({}).should.eql true
      moduleObj.Array([]).should.eql true
      moduleObj.String(new String).should.eql true
      moduleObj.Function(() ->).should.eql true
      moduleObj.Date(new Date).should.eql true

  describe 'deepDeserialize()', () ->

    before () ->
      @original =
        arr: [
          (arg) -> "Hello #{arg}!"
          'hello!'
          1
          (arg) -> "Goodbye #{arg}!"
          {
            foo: 'bar'
            foobar: (arg) -> "FOOBAR: #{arg}"
          }
        ]
        obj:
          a: [
            {
              b: {
                c: (arg) -> "Super deep! #{arg}"
              }
            }
          ]
          z: 'just a string!'
      @serialized = funcster.deepSerialize(@original)
      @deserialized = funcster.deepDeserialize(@serialized)

    describe 'overloaded signature', () ->

      it 'one arg: root', () ->
        serialized = { __js_function: 'function() { return "hello" }' }
        deserialized = funcster.deepDeserialize(serialized)
        deserialized().should.eql 'hello'

      it 'two args: root, marker', () ->
        serialized = { CUSTOM_MARKER: 'function() { return "hello" }' }
        deserialized = funcster.deepDeserialize(serialized, 'CUSTOM_MARKER')
        deserialized().should.eql 'hello'

      it 'two args: root, moduleOpts', () ->
        serialized = { __js_function: 'function() { return foobar }' }
        deserialized = funcster.deepDeserialize(serialized, globals: { foobar: 'hello' })
        deserialized().should.eql 'hello'

      it 'three args: root, marker, moduleOpts', () ->
        serialized = { CUSTOM_MARKER: 'function() { return foobar }' }
        deserialized = funcster.deepDeserialize(serialized, 'CUSTOM_MARKER', globals: { foobar: 'hello' })
        deserialized().should.eql 'hello'

    it 'deserialized functions should work like unserialized versions', () ->
      @deserialized.arr[0]('world').should.eql @original.arr[0]('world')
      @deserialized.arr[3]('world').should.eql @original.arr[3]('world')
      @deserialized.arr[4].foobar('world').should.eql @original.arr[4].foobar('world')
      @deserialized.obj.a[0].b.c('world').should.eql @original.obj.a[0].b.c('world')

    it 'deserialized functions should not be copies of the unserialized versions', () ->
      # We use this slightly strange syntax because the functions in @deserialized
      # derive from an Object base class in a different context, so it has not
      # been extended by the should module.
      (@deserialized.arr[0] != @original.arr[0]).should.eql true
      (@deserialized.arr[3] != @original.arr[3]).should.eql true
      (@deserialized.arr[4].foobar != @original.arr[4].foobar).should.eql true
      (@deserialized.obj.a[0].b.c != @original.obj.a[0].b.c).should.eql true

    it 'should preserve the original structure', () ->
      @deserialized.arr[1].should.eql @original.arr[1]
      @deserialized.obj.z.should.eql @original.obj.z