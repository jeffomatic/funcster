_ = require('underscore')
assert = require('assert')
testHelper = require('./test_helper')
funcster = require('../lib/funcster')

describe 'funcster module', () ->

  describe 'serialize()', () ->

    before () ->
      @testFunc = (arg) -> "Hello #{arg}!"
      @serializedTestFunc = funcster.serialize(@testFunc)

    it 'should wrap a function in an object', () ->
      assert.deepEqual _.keys(@serializedTestFunc), [ '__js_function' ]

    it 'should serialize the function to a string', () ->
      assert.equal @serializedTestFunc.__js_function, @testFunc.toString()

    it 'should allow for custom serialization markers', () ->
      serialzed = funcster.serialize(@testFunc, 'CUSTOM_MARKER')
      assert.deepEqual _.keys(serialzed), [ 'CUSTOM_MARKER' ]

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
      assert.equal @serialized.arr[0].__js_function, @original.arr[0].toString()
      assert.equal @serialized.arr[3].__js_function, @original.arr[3].toString()
      assert.equal @serialized.arr[4].foobar.__js_function, @original.arr[4].foobar.toString()
      assert.equal @serialized.obj.a[0].b.c.__js_function, @original.obj.a[0].b.c.toString()

    it 'should retain non-function values', () ->
      assert.equal @serialized.arr[1], 'hello!'
      assert.equal @serialized.arr[2], 1
      assert.equal @serialized.arr[4].foo, 'bar'
      assert.equal @serialized.obj.z, 'just a string!'

  describe '_deepSelectSerializations()', () ->

    before () ->
      @selected = funcster._deepSelectSerializations(@serialized)

    it 'should collect all serialized functions', () ->
      assert.equal @selected.length, 4

    it 'should set paths correctly', () ->
      assert.deepEqual @selected[0].path, [ 'arr', '0' ]
      assert.deepEqual @selected[1].path, [ 'arr', '3' ]
      assert.deepEqual @selected[2].path, [ 'arr', '4', 'foobar' ]
      assert.deepEqual @selected[3].path, [ 'obj', 'a', '0', 'b', 'c' ]

  describe '_generateModuleScript()', () ->

    it 'should encode functions into a text script', () ->
      functions =
        'func_a': 'function(arg) { return arg; }'
        'func_b': 'function(arg) { return [ arg ]; }'

      script = funcster._generateModuleScript(functions)
      script.should.eql 'module.exports=(function(module,exports){return{func_a: function(arg) { return arg; },func_b: function(arg) { return [ arg ]; }};})();'

  describe '_rerequire', () ->

    before () ->
      @cacheSizeBefore = _.size(require.cache)
      @rerequired = funcster._rerequire
        _: 'underscore'
        funcster: '../lib/funcster'
        dummyModule: '../../test/dummy_module'
      @cacheSizeAfter = _.size(require.cache)

    it 'should preserve the require cache', () ->
      assert.equal _, require('underscore')
      assert.equal funcster, require('../lib/funcster')

    it 'should not add new modules to the require cache', () ->
      assert.equal @cacheSizeBefore, @cacheSizeAfter

    it 'should generate new copies of pre-existing modules', () ->
      assert.notEqual _, @rerequired._
      assert.notEqual funcster, @rerequired.funcster

  describe '_generateModule()', () ->

    it 'should export objects', () ->
      func = (arg) -> "Hello #{arg}!"
      script = "module.exports = { foo: #{func.toString()} }"
      moduleObj = funcster._generateModule(script)

      assert moduleObj?
      assert moduleObj.foo?
      assert.equal moduleObj.foo('world'), 'Hello world!'

    it 'should not include typical node.js globals by default', () ->
      objects = [ 'global', 'process', 'require', 'setTimeout', 'clearTimeout',
        'setInterval', 'clearInterval', 'console', 'Buffer', '__filename',
        '__dirname' ]
      functions = []
      functions.push "#{obj}: function() { #{obj}; }" for obj in objects
      script = 'module.exports = {' + functions.join(',') + '}'
      moduleObj = funcster._generateModule(script)

      for obj in objects
        assert.throws (() -> moduleObj[obj]()), /is not defined/

    it 'should have falsy values for modules and exports when using standard template', () ->
      objects = [ 'module', 'exports' ]
      functions = {}
      functions[obj] = "function() { return !#{obj}; }" for obj in objects
      script = funcster._generateModuleScript(functions)
      moduleObj = funcster._generateModule(script)

      assert(moduleObj[obj]()) for obj in objects

    it 'should define standard global values', () ->
      objects = [ 'Object', 'Array', 'String', 'Date', 'Function' ]
      functions = {}
      functions[obj] = "function() { return !!#{obj}; }" for obj in objects
      script = funcster._generateModuleScript(functions)
      moduleObj = funcster._generateModule(script)

      assert(moduleObj[obj]()) for obj in objects

    it 'instanceof operator fails by default', () ->
      objects = [ 'Object', 'Array', 'String', 'Date', 'Function' ]
      functions = {}
      functions[obj] = "function(arg) { return arg instanceof #{obj}; }" for obj in objects
      script = funcster._generateModuleScript(functions)
      moduleObj = funcster._generateModule(script)

      assert !moduleObj.Object({})
      assert !moduleObj.Array([])
      assert !moduleObj.String(new String)
      assert !moduleObj.Function(() ->)
      assert !moduleObj.Date(new Date)

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

      assert moduleObj.Object({})
      assert moduleObj.Array([])
      assert moduleObj.String(new String)
      assert moduleObj.Function(() ->)
      assert moduleObj.Date(new Date)

    describe 'injection using requires option', () ->

      it 'grants access to modules', () ->
        script = funcster._generateModuleScript(testFunc: 'function(arg) { return _.max(arg); }')
        moduleObj = funcster._generateModule(script, requires: {_: 'underscore'})

        assert.equal moduleObj.testFunc([1, 2, 3]), _.max([1, 2, 3])

      it 'uses different module objects', () ->
        _.temp = () ->
        script = funcster._generateModuleScript(testFunc: 'function(arg) { return _.temp(); }')
        moduleObj = funcster._generateModule(script, requires: {_: 'underscore'})

        assert.throws (() ->moduleObj.testFunc()), /TypeError/

      describe 'injecting underscore', () ->
        before () ->
          functions =
            getUnderscore: 'function() { return _; }'
            isFunction: 'function() { return _.isFunction(function(){}); }'
            isArray: 'function() { return _.isArray([]); }'
            isObject: 'function() { return _.isObject({}); }'
            isString: 'function() { return _.isString(""); }'
            isNumber: 'function() { return _.isNumber(5); }'
            isBoolean: 'function() { return _.isBoolean(true); }'
            isDate: 'function() { return _.isDate(new Date); }'
            isRegExp: 'function() { return _.isRegExp(/test/); }'
            isNull: 'function() { return _.isNull(null); }'
            isUndefined: 'function() { return _.isUndefined(undefined); }'

          script = funcster._generateModuleScript(functions)
          @moduleObj = funcster._generateModule(script, requires: {_: 'underscore'})

        it 'should preserve type check functions for primordial objects created in the current context', () ->
          underscore2 = @moduleObj.getUnderscore()

          assert underscore2.isFunction(() ->)
          assert underscore2.isArray([])
          assert underscore2.isObject({})
          assert underscore2.isString('')
          assert underscore2.isNumber(5)
          assert underscore2.isBoolean(true)
          assert underscore2.isDate(new Date)
          assert underscore2.isRegExp(/test/)
          assert underscore2.isNull(null)
          assert underscore2.isUndefined(undefined)

        it 'should preserve type check functions for primordial objects created in the evaluation context', () ->
          assert @moduleObj.isFunction()
          assert @moduleObj.isArray()
          assert @moduleObj.isObject()
          assert @moduleObj.isString()
          assert @moduleObj.isNumber()
          assert @moduleObj.isBoolean()
          assert @moduleObj.isDate()
          assert @moduleObj.isRegExp()
          assert @moduleObj.isNull()
          assert @moduleObj.isUndefined()

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

        assert.equal deserialized(), 'hello'

      it 'two args: root, marker', () ->
        serialized = { CUSTOM_MARKER: 'function() { return "hello" }' }
        deserialized = funcster.deepDeserialize(serialized, 'CUSTOM_MARKER')

        assert.equal deserialized(), 'hello'

      it 'two args: root, moduleOpts', () ->
        serialized = { __js_function: 'function() { return foobar }' }
        deserialized = funcster.deepDeserialize(serialized, globals: { foobar: 'hello' })

        assert.equal deserialized(), 'hello'

      it 'three args: root, marker, moduleOpts', () ->
        serialized = { CUSTOM_MARKER: 'function() { return foobar }' }
        deserialized = funcster.deepDeserialize(serialized, 'CUSTOM_MARKER', globals: { foobar: 'hello' })

        assert.equal deserialized(), 'hello'

    it 'deserialized functions should work like unserialized versions', () ->
      assert.equal @deserialized.arr[0]('world'), @original.arr[0]('world')
      assert.equal @deserialized.arr[3]('world'), @original.arr[3]('world')
      assert.equal @deserialized.arr[4].foobar('world'), @original.arr[4].foobar('world')
      assert.equal @deserialized.obj.a[0].b.c('world'), @original.obj.a[0].b.c('world')

    it 'deserialized functions should not be copies of the unserialized versions', () ->
      assert.notEqual @deserialized.arr[0], @original.arr[0]
      assert.notEqual @deserialized.arr[3], @original.arr[3]
      assert.notEqual @deserialized.arr[4].foobar, @original.arr[4].foobar
      assert.notEqual @deserialized.obj.a[0].b.c, @original.obj.a[0].b.c

    it 'should preserve the original structure', () ->
      assert.equal @deserialized.arr[1], @original.arr[1]
      assert.equal @deserialized.obj.z, @original.obj.z