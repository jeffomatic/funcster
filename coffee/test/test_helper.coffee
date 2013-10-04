_ = require 'underscore'
exampleFns = require '../../deps/example_functions'

process.env.NODE_ENV = "test"
module.exports =
  bubblesort: (list) ->
    for i in [0...list.length]
      for j in [0...list.length - i]
        [list[j], list[j+1]] = [list[j+1], list[j]] if list[j] > list[j+1]
    list

_.extend(module.exports, exampleFns)