# This is used as an example function to test minification
# Taken from the CoffeeScript examples. https://github.com/jashkenas/coffee-script/blob/master/examples/computer_science/bubble_sort.coffee

bubblesort = (list) ->
  for i in [0...list.length]
    for j in [0...list.length - i]
      [list[j], list[j+1]] = [list[j+1], list[j]] if list[j] > list[j+1]
  list

module.exports = bubblesort