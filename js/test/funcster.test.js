// Generated by CoffeeScript 1.6.3
(function() {
  var assert, funcster, testHelper, _;

  _ = require('underscore');

  assert = require('assert');

  testHelper = require('./test_helper');

  funcster = require('../lib/funcster');

  describe('funcster module', function() {
    describe('serialize()', function() {
      before(function() {
        this.testFunc = function(arg) {
          return "Hello " + arg + "!";
        };
        return this.serializedTestFunc = funcster.serialize(this.testFunc);
      });
      it('should wrap a function in an object', function() {
        return assert.deepEqual(_.keys(this.serializedTestFunc), ['__js_function']);
      });
      it('should serialize the function to a string', function() {
        return assert.equal(this.serializedTestFunc.__js_function.replace(/\s/g, ''), this.testFunc.toString().replace(/\s/g, ''));
      });
      return it('should allow for custom serialization markers', function() {
        var serialzed;
        serialzed = funcster.serialize(this.testFunc, 'CUSTOM_MARKER');
        return assert.deepEqual(_.keys(serialzed), ['CUSTOM_MARKER']);
      });
    });
    describe('serialize with nontrivial functions', function() {
      before(function() {
        this.testFunc = testHelper.bubblesort;
        this.serializedTestFunc = funcster.serialize(this.testFunc);
        return this.deserializedTestFunc = funcster.deepDeserialize(this.serializedTestFunc);
      });
      it('should minify the function', function() {
        return assert(this.testFunc.toString().length > this.serializedTestFunc.__js_function.length);
      });
      return it('should still function the same', function() {
        var testObj;
        testObj = [5, 4, 3, 2, 6, 12, 14];
        return assert.equal(this.deserializedTestFunc(testObj), this.testFunc(testObj));
      });
    });
    describe('serialize with whitespace differences', function() {
      before(function() {
        this.serializedCoffeeScriptFn = funcster.serialize(testHelper.compiledByCoffeeScript);
        this.serializedIndentedFn = funcster.serialize(testHelper.withALeadingIndent);
        return this.serializedNewlineFn = funcster.serialize(testHelper.withExcessiveNewlines);
      });
      return it('should serialize to the same string', function() {
        assert.deepEqual(this.serializedCoffeeScriptFn, this.serializedIndentedFn);
        return assert.deepEqual(this.serializedIndentedFn, this.serializedNewlineFn);
      });
    });
    describe('deepSerialize()', function() {
      before(function() {
        this.original = {
          arr: [
            function(arg) {
              return "Hello " + arg + "!";
            }, 'hello!', 1, function(arg) {
              return "Goodbye " + arg + "!";
            }, {
              foo: 'bar',
              foobar: function(arg) {
                return "FOOBAR: " + arg;
              }
            }
          ],
          obj: {
            a: [
              {
                b: {
                  c: function(arg) {
                    return "Super deep! " + arg;
                  }
                }
              }
            ],
            z: 'just a string!'
          }
        };
        return this.serialized = funcster.deepSerialize(this.original);
      });
      it('should serialize deeply nested functions', function() {
        assert.equal(this.serialized.arr[0].__js_function.replace(/\s/g, ''), this.original.arr[0].toString().replace(/\s/g, ''));
        assert.equal(this.serialized.arr[3].__js_function.replace(/\s/g, ''), this.original.arr[3].toString().replace(/\s/g, ''));
        assert.equal(this.serialized.arr[4].foobar.__js_function.replace(/\s/g, ''), this.original.arr[4].foobar.toString().replace(/\s/g, ''));
        return assert.equal(this.serialized.obj.a[0].b.c.__js_function.replace(/\s/g, ''), this.original.obj.a[0].b.c.toString().replace(/\s/g, ''));
      });
      return it('should retain non-function values', function() {
        assert.equal(this.serialized.arr[1], 'hello!');
        assert.equal(this.serialized.arr[2], 1);
        assert.equal(this.serialized.arr[4].foo, 'bar');
        return assert.equal(this.serialized.obj.z, 'just a string!');
      });
    });
    describe('_deepSelectSerializations()', function() {
      before(function() {
        return this.selected = funcster._deepSelectSerializations(this.serialized);
      });
      it('should collect all serialized functions', function() {
        return assert.equal(this.selected.length, 4);
      });
      return it('should set paths correctly', function() {
        assert.deepEqual(this.selected[0].path, ['arr', '0']);
        assert.deepEqual(this.selected[1].path, ['arr', '3']);
        assert.deepEqual(this.selected[2].path, ['arr', '4', 'foobar']);
        return assert.deepEqual(this.selected[3].path, ['obj', 'a', '0', 'b', 'c']);
      });
    });
    describe('_generateModuleScript()', function() {
      return it('should encode functions into a text script', function() {
        var functions, script;
        functions = {
          'func_a': 'function(arg) { return arg; }',
          'func_b': 'function(arg) { return [ arg ]; }',
          'complicated -" *$@ name': 'function(arg) { return arg; }'
        };
        script = funcster._generateModuleScript(functions);
        return assert.equal(script, 'module.exports=(function(module,exports){return{"func_a": function(arg) { return arg; },"func_b": function(arg) { return [ arg ]; },"complicated -\\" *$@ name": function(arg) { return arg; }};})();');
      });
    });
    describe('_rerequire', function() {
      before(function() {
        this.cacheSizeBefore = _.size(require.cache);
        this.rerequired = funcster._rerequire({
          _: 'underscore',
          funcster: '../lib/funcster',
          dummyModule: '../../test/dummy_module'
        });
        return this.cacheSizeAfter = _.size(require.cache);
      });
      it('should preserve the require cache', function() {
        assert.equal(_, require('underscore'));
        return assert.equal(funcster, require('../lib/funcster'));
      });
      it('should not add new modules to the require cache', function() {
        return assert.equal(this.cacheSizeBefore, this.cacheSizeAfter);
      });
      return it('should generate new copies of pre-existing modules', function() {
        assert.notEqual(_, this.rerequired._);
        return assert.notEqual(funcster, this.rerequired.funcster);
      });
    });
    describe('_generateModule()', function() {
      it('should export objects', function() {
        var func, moduleObj, script;
        func = function(arg) {
          return "Hello " + arg + "!";
        };
        script = "module.exports = { foo: " + (func.toString()) + " }";
        moduleObj = funcster._generateModule(script);
        assert(moduleObj != null);
        assert(moduleObj.foo != null);
        return assert.equal(moduleObj.foo('world'), 'Hello world!');
      });
      it('should not include typical node.js globals by default', function() {
        var functions, moduleObj, obj, objects, script, _i, _j, _len, _len1, _results;
        objects = ['global', 'process', 'require', 'setTimeout', 'clearTimeout', 'setInterval', 'clearInterval', 'console', 'Buffer', '__filename', '__dirname'];
        functions = [];
        for (_i = 0, _len = objects.length; _i < _len; _i++) {
          obj = objects[_i];
          functions.push("" + obj + ": function() { " + obj + "; }");
        }
        script = 'module.exports = {' + functions.join(',') + '}';
        moduleObj = funcster._generateModule(script);
        _results = [];
        for (_j = 0, _len1 = objects.length; _j < _len1; _j++) {
          obj = objects[_j];
          _results.push(assert.throws((function() {
            return moduleObj[obj]();
          }), /is not defined/));
        }
        return _results;
      });
      it('should have falsy values for modules and exports when using standard template', function() {
        var functions, moduleObj, obj, objects, script, _i, _j, _len, _len1, _results;
        objects = ['module', 'exports'];
        functions = {};
        for (_i = 0, _len = objects.length; _i < _len; _i++) {
          obj = objects[_i];
          functions[obj] = "function() { return !" + obj + "; }";
        }
        script = funcster._generateModuleScript(functions);
        moduleObj = funcster._generateModule(script);
        _results = [];
        for (_j = 0, _len1 = objects.length; _j < _len1; _j++) {
          obj = objects[_j];
          _results.push(assert(moduleObj[obj]()));
        }
        return _results;
      });
      it('should define standard global values', function() {
        var functions, moduleObj, obj, objects, script, _i, _j, _len, _len1, _results;
        objects = ['Object', 'Array', 'String', 'Date', 'Function'];
        functions = {};
        for (_i = 0, _len = objects.length; _i < _len; _i++) {
          obj = objects[_i];
          functions[obj] = "function() { return !!" + obj + "; }";
        }
        script = funcster._generateModuleScript(functions);
        moduleObj = funcster._generateModule(script);
        _results = [];
        for (_j = 0, _len1 = objects.length; _j < _len1; _j++) {
          obj = objects[_j];
          _results.push(assert(moduleObj[obj]()));
        }
        return _results;
      });
      it('instanceof operator fails by default', function() {
        var functions, moduleObj, obj, objects, script, _i, _len;
        objects = ['Object', 'Array', 'String', 'Date', 'Function'];
        functions = {};
        for (_i = 0, _len = objects.length; _i < _len; _i++) {
          obj = objects[_i];
          functions[obj] = "function(arg) { return arg instanceof " + obj + "; }";
        }
        script = funcster._generateModuleScript(functions);
        moduleObj = funcster._generateModule(script);
        assert(!moduleObj.Object({}));
        assert(!moduleObj.Array([]));
        assert(!moduleObj.String(new String));
        assert(!moduleObj.Function(function() {}));
        return assert(!moduleObj.Date(new Date));
      });
      it('instanceof operator succeeds with global injection', function() {
        var functions, moduleObj, obj, objects, script, _i, _len;
        objects = ['Object', 'Array', 'String', 'Date', 'Function'];
        functions = {};
        for (_i = 0, _len = objects.length; _i < _len; _i++) {
          obj = objects[_i];
          functions[obj] = "function(arg) { return arg instanceof " + obj + "; }";
        }
        script = funcster._generateModuleScript(functions);
        moduleObj = funcster._generateModule(script, {
          globals: {
            Object: Object,
            Array: Array,
            String: String,
            Function: Function,
            Date: Date
          }
        });
        assert(moduleObj.Object({}));
        assert(moduleObj.Array([]));
        assert(moduleObj.String(new String));
        assert(moduleObj.Function(function() {}));
        return assert(moduleObj.Date(new Date));
      });
      return describe('injection using requires option', function() {
        it('grants access to modules', function() {
          var moduleObj, script;
          script = funcster._generateModuleScript({
            testFunc: 'function(arg) { return _.max(arg); }'
          });
          moduleObj = funcster._generateModule(script, {
            requires: {
              _: 'underscore'
            }
          });
          return assert.equal(moduleObj.testFunc([1, 2, 3]), _.max([1, 2, 3]));
        });
        it('uses different module objects', function() {
          var moduleObj, script;
          _.temp = function() {};
          script = funcster._generateModuleScript({
            testFunc: 'function(arg) { return _.temp(); }'
          });
          moduleObj = funcster._generateModule(script, {
            requires: {
              _: 'underscore'
            }
          });
          return assert.throws((function() {
            return moduleObj.testFunc();
          }), /TypeError/);
        });
        return describe('injecting underscore', function() {
          before(function() {
            var functions, script;
            functions = {
              getUnderscore: 'function() { return _; }',
              isFunction: 'function() { return _.isFunction(function(){}); }',
              isArray: 'function() { return _.isArray([]); }',
              isObject: 'function() { return _.isObject({}); }',
              isString: 'function() { return _.isString(""); }',
              isNumber: 'function() { return _.isNumber(5); }',
              isBoolean: 'function() { return _.isBoolean(true); }',
              isDate: 'function() { return _.isDate(new Date); }',
              isRegExp: 'function() { return _.isRegExp(/test/); }',
              isNull: 'function() { return _.isNull(null); }',
              isUndefined: 'function() { return _.isUndefined(undefined); }'
            };
            script = funcster._generateModuleScript(functions);
            return this.moduleObj = funcster._generateModule(script, {
              requires: {
                _: 'underscore'
              }
            });
          });
          it('should preserve type check functions for primordial objects created in the current context', function() {
            var underscore2;
            underscore2 = this.moduleObj.getUnderscore();
            assert(underscore2.isFunction(function() {}));
            assert(underscore2.isArray([]));
            assert(underscore2.isObject({}));
            assert(underscore2.isString(''));
            assert(underscore2.isNumber(5));
            assert(underscore2.isBoolean(true));
            assert(underscore2.isDate(new Date));
            assert(underscore2.isRegExp(/test/));
            assert(underscore2.isNull(null));
            return assert(underscore2.isUndefined(void 0));
          });
          return it('should preserve type check functions for primordial objects created in the evaluation context', function() {
            assert(this.moduleObj.isFunction());
            assert(this.moduleObj.isArray());
            assert(this.moduleObj.isObject());
            assert(this.moduleObj.isString());
            assert(this.moduleObj.isNumber());
            assert(this.moduleObj.isBoolean());
            assert(this.moduleObj.isDate());
            assert(this.moduleObj.isRegExp());
            assert(this.moduleObj.isNull());
            return assert(this.moduleObj.isUndefined());
          });
        });
      });
    });
    return describe('deepDeserialize()', function() {
      before(function() {
        this.original = {
          arr: [
            function(arg) {
              return "Hello " + arg + "!";
            }, 'hello!', 1, function(arg) {
              return "Goodbye " + arg + "!";
            }, {
              foo: 'bar',
              foobar: function(arg) {
                return "FOOBAR: " + arg;
              }
            }
          ],
          obj: {
            a: [
              {
                b: {
                  c: function(arg) {
                    return "Super deep! " + arg;
                  }
                }
              }
            ],
            z: 'just a string!'
          }
        };
        this.serialized = funcster.deepSerialize(this.original);
        return this.deserialized = funcster.deepDeserialize(this.serialized);
      });
      describe('overloaded signature', function() {
        it('one arg: root', function() {
          var deserialized, serialized;
          serialized = {
            __js_function: 'function() { return "hello" }'
          };
          deserialized = funcster.deepDeserialize(serialized);
          return assert.equal(deserialized(), 'hello');
        });
        it('two args: root, marker', function() {
          var deserialized, serialized;
          serialized = {
            CUSTOM_MARKER: 'function() { return "hello" }'
          };
          deserialized = funcster.deepDeserialize(serialized, 'CUSTOM_MARKER');
          return assert.equal(deserialized(), 'hello');
        });
        it('two args: root, moduleOpts', function() {
          var deserialized, serialized;
          serialized = {
            __js_function: 'function() { return foobar }'
          };
          deserialized = funcster.deepDeserialize(serialized, {
            globals: {
              foobar: 'hello'
            }
          });
          return assert.equal(deserialized(), 'hello');
        });
        return it('three args: root, marker, moduleOpts', function() {
          var deserialized, serialized;
          serialized = {
            CUSTOM_MARKER: 'function() { return foobar }'
          };
          deserialized = funcster.deepDeserialize(serialized, 'CUSTOM_MARKER', {
            globals: {
              foobar: 'hello'
            }
          });
          return assert.equal(deserialized(), 'hello');
        });
      });
      it('deserialized functions should work like unserialized versions', function() {
        assert.equal(this.deserialized.arr[0]('world'), this.original.arr[0]('world'));
        assert.equal(this.deserialized.arr[3]('world'), this.original.arr[3]('world'));
        assert.equal(this.deserialized.arr[4].foobar('world'), this.original.arr[4].foobar('world'));
        return assert.equal(this.deserialized.obj.a[0].b.c('world'), this.original.obj.a[0].b.c('world'));
      });
      it('deserialized functions should not be copies of the unserialized versions', function() {
        assert.notEqual(this.deserialized.arr[0], this.original.arr[0]);
        assert.notEqual(this.deserialized.arr[3], this.original.arr[3]);
        assert.notEqual(this.deserialized.arr[4].foobar, this.original.arr[4].foobar);
        return assert.notEqual(this.deserialized.obj.a[0].b.c, this.original.obj.a[0].b.c);
      });
      return it('should preserve the original structure', function() {
        assert.equal(this.deserialized.arr[1], this.original.arr[1]);
        return assert.equal(this.deserialized.obj.z, this.original.obj.z);
      });
    });
  });

}).call(this);
