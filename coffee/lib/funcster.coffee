_ = require('underscore')
vm = require('vm')
deep = require('deep')

# funcster - function serialization utilities
funcster =

  serialize: (func, marker = '__js_function') ->
    wrapper = {}
    wrapper[marker] = func.toString()
    wrapper

  # Recursively traverses objects and replaces functions with object-wrapped,
  # serialized strings.
  deepSerialize: (root, marker = '__js_function') ->
    deep.transform root, _.isFunction, (func) ->
      funcster.serialize(func, marker)

  # Recursively traverses objects and replaces serialized functions with actual
  # functions.
  #
  # You can call this function with a variety of different arguments:
  # @root {object}
  #
  # @root {object}
  # @marker {string}
  #
  # @root {object}
  # @moduleOpts {object}
  #
  # @root {object}
  # @marker {string}
  # @moduleOpts {object}
  deepDeserialize: (root, extraArgs...) ->
    switch extraArgs.length
      when 0
        marker = '__js_function'
        moduleOpts = {}
      when 1
        if _.isString(extraArgs[0])
          marker = extraArgs[0]
          moduleOpts = {}
        else
          marker = '__js_function'
          moduleOpts = extraArgs[0]
      else
        marker = extraArgs[0]
        moduleOpts = extraArgs[1]

    # Don't modify the original root
    root = deep.clone(root)

    # Collect paths to nested serializations
    functions = @_deepSelectSerializations(root, marker)

    # Assign names to each function based on their path
    f.name = "func_" + f.path.join('_') for f in functions

    # Create a mapping between function names and function bodies
    functionsByName = {}
    functionsByName[f.name] = f.value[marker] for f in functions

    # Generate runtime functions from the serializaitons
    moduleContent = @_generateModuleScript(functionsByName)
    moduleObj = @_generateModule(moduleContent, moduleOpts)

    # Assign actual functions in place of serializations
    for f in functions
      return moduleObj[f.name] unless f.path.length # edge case: the root itself is a function
      deep.set(root, f.path, moduleObj[f.name])

    # Done!
    root

  # Recusrively traverses objects and collects serialized functions, along with
  # the path of references required to access the serialization.
  _deepSelectSerializations: (root, marker = '__js_function') ->
    deep.select root, (obj) -> _.isObject(obj) && _.isString(obj[marker])

  # Builds a text/javascript representation of a collection of functions.
  _generateModuleScript: (serializedFunctions) ->
    entries = []
    entries.push("#{name}: #{body}") for name, body of serializedFunctions
    entries = entries.join(',')
    "module.exports=(function(global,module,exports){return{#{entries}};})();"

  # Given a text/javascript representation of an object, execute that
  # representation as a script and return it as a module.
  _generateModule: (content, opts = {}) ->
    # Create blank sandbox
    sandbox = {}
    exportsObj = {}

    sandbox.global = sandbox
    sandbox.exports = exportsObj
    sandbox.module = { exports: exportsObj }

    # Add libs
    globals = opts.globals || {}
    sandbox.global[k] = v for k, v of globals

    # Generate runtime script and execute in sandbox.
    vm.createScript(content, opts.filename).runInNewContext(sandbox)

    # Running the script should have updated the exports.
    sandbox.module.exports

module.exports = funcster
