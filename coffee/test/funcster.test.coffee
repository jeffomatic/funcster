_ = require('underscore')
should = require('should')
testHelper = require('./test_helper')
funcster = require('../lib/funcster')

describe 'funcster module', () ->

  describe 'serialize()', () ->

    before (done) ->
      @testFunc = (arg) -> "Hello #{arg}!"
      @serializedTestFunc = funcster.serialize(@testFunc)
      done()

    it 'should wrap a function in an object', (done) ->
      _.keys(@serializedTestFunc).should.eql [ '__js_function' ]
      done()

    it 'should serialize the function to a string', (done) ->
      @serializedTestFunc.__js_function.should.eql @testFunc.toString()
      done()

    it 'should allow for custom serialization markers', (done) ->
      serialzed = funcster.serialize(@testFunc, 'CUSTOM_MARKER')
      _.keys(serialzed).should.eql [ 'CUSTOM_MARKER' ]
      done()

  describe 'deepSerialize()', () ->

    before (done) ->
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
      done()

    it 'should serialize deeply nested functions', (done) ->
      @serialized.arr[0].__js_function.should.eql @original.arr[0].toString()
      @serialized.arr[3].__js_function.should.eql @original.arr[3].toString()
      @serialized.arr[4].foobar.__js_function.should.eql @original.arr[4].foobar.toString()
      @serialized.obj.a[0].b.c.__js_function.should.eql @original.obj.a[0].b.c.toString()
      done()

    it 'should retain non-function values', (done) ->
      @serialized.arr[1].should.eql 'hello!'
      @serialized.arr[2].should.eql 1
      @serialized.arr[4].foo.should.eql 'bar'
      @serialized.obj.z.should.eql 'just a string!'
      done()

  describe '_deepSelectSerializations()', () ->

    before (done) ->
      @selected = funcster._deepSelectSerializations(@serialized)
      done()

    it 'should collect all serialized functions', (done) ->
      @selected.length.should.eql 4
      done()

    it 'should set paths correctly', (done) ->
      @selected[0].path.should.eql [ 'arr', '0' ]
      @selected[1].path.should.eql [ 'arr', '3' ]
      @selected[2].path.should.eql [ 'arr', '4', 'foobar' ]
      @selected[3].path.should.eql [ 'obj', 'a', '0', 'b', 'c' ]
      done()

  describe '_generateModuleScript()', () ->

    it 'should encode functions into a text script', (done) ->
      functions =
        'func_a': 'function(arg) { return arg; }'
        'func_b': 'function(arg) { return [ arg ]; }'

      script = funcster._generateModuleScript(functions)
      script.should.eql 'module.exports=(function(global,module,exports){return{func_a: function(arg) { return arg; },func_b: function(arg) { return [ arg ]; }};})();'

      done()

  describe '_generateModule()', () ->

    it 'should export objects', (done) ->
      func = (arg) -> "Hello #{arg}!"
      script = "module.exports = { foo: #{func.toString()} }"
      moduleObj = funcster._generateModule(script)
      (moduleObj?).should.eql true
      (moduleObj.foo?).should.eql true
      moduleObj.foo('world').should.eql 'Hello world!'
      done()

    it 'should not include typical node.js globals by default', (done) ->
      objects = [ 'process', 'require', 'setTimeout', 'clearTimeout',
        'setInterval', 'clearInterval', 'console', 'Buffer', '__filename',
        '__dirname' ]
      functions = []
      functions.push "#{obj}: function() { #{obj}; }" for obj in objects
      script = 'module.exports = {' + functions.join(',') + '}'
      moduleObj = funcster._generateModule(script)
      (() -> moduleObj[obj]()).should.throw /is not defined/ for obj in objects
      done()

    it 'should have falsy values for global, modules and exports when using standard template', (done) ->
      objects = [ 'global', 'module', 'exports' ]
      functions = {}
      functions[obj] = "function() { return !#{obj}; }" for obj in objects
      script = funcster._generateModuleScript(functions)
      moduleObj = funcster._generateModule(script)
      moduleObj[obj]().should.eql true for obj in objects
      done()

    it 'should define standard global values', (done) ->
      objects = [ 'Object', 'Array', 'String', 'Date', 'Function' ]
      functions = {}
      functions[obj] = "function() { return !!#{obj}; }" for obj in objects
      script = funcster._generateModuleScript(functions)
      moduleObj = funcster._generateModule(script)
      moduleObj[obj]().should.eql true for obj in objects
      done()

    it 'instanceof operator fails by default', (done) ->
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
      done()

    it 'instanceof operator succeeds with global injection', (done) ->
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
      done()

  describe 'deepDeserialize()', () ->

    before (done) ->
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
      done()

    describe 'overloaded signature', () ->

      it 'one arg: root', (done) ->
        serialized = { __js_function: 'function() { return "hello" }' }
        deserialized = funcster.deepDeserialize(serialized)
        deserialized().should.eql 'hello'
        done()

      it 'two args: root, marker', (done) ->
        serialized = { CUSTOM_MARKER: 'function() { return "hello" }' }
        deserialized = funcster.deepDeserialize(serialized, 'CUSTOM_MARKER')
        deserialized().should.eql 'hello'
        done()

      it 'two args: root, moduleOpts', (done) ->
        serialized = { __js_function: 'function() { return foobar }' }
        deserialized = funcster.deepDeserialize(serialized, globals: { foobar: 'hello' })
        deserialized().should.eql 'hello'
        done()

      it 'three args: root, marker, moduleOpts', (done) ->
        serialized = { CUSTOM_MARKER: 'function() { return foobar }' }
        deserialized = funcster.deepDeserialize(serialized, 'CUSTOM_MARKER', globals: { foobar: 'hello' })
        deserialized().should.eql 'hello'
        done()

    it 'deserialized functions should work like unserialized versions', (done) ->
      @deserialized.arr[0]('world').should.eql @original.arr[0]('world')
      @deserialized.arr[3]('world').should.eql @original.arr[3]('world')
      @deserialized.arr[4].foobar('world').should.eql @original.arr[4].foobar('world')
      @deserialized.obj.a[0].b.c('world').should.eql @original.obj.a[0].b.c('world')
      done()

    it 'deserialized functions should not be copies of the unserialized versions', (done) ->
      # We use this slightly strange syntax because the functions in @deserialized
      # derive from an Object base class in a different context, so it has not
      # been extended by the should module.
      (@deserialized.arr[0] != @original.arr[0]).should.eql true
      (@deserialized.arr[3] != @original.arr[3]).should.eql true
      (@deserialized.arr[4].foobar != @original.arr[4].foobar).should.eql true
      (@deserialized.obj.a[0].b.c != @original.obj.a[0].b.c).should.eql true
      done()

    it 'should preserve the original structure', (done) ->
      @deserialized.arr[1].should.eql @original.arr[1]
      @deserialized.obj.z.should.eql @original.obj.z
      done()