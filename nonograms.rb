require "json"
require "pry"
# require "pry-byebug"
require "rainbow"

require "./board"
require "./board_view"
require "./clue"
require "./clue_set"
require "./clue_set_view"
require "./puzzle"

start = Time.now.utc

# puzzle = Puzzle.from_file("ladybug.20x20")
# puzzle = Puzzle.from_file("pumpkins.45x35")
# puzzle = Puzzle.from_file("hare.30x35")
# puzzle = Puzzle.from_file("online_nonograms_com/17465")
# puzzle = Puzzle.from_file("online_nonograms_com/19268")
# puzzle = Puzzle.from_file("online_nonograms_com/19262")
# puzzle = Puzzle.from_file("online_nonograms_com/19267")
# puzzle = Puzzle.from_file("online_nonograms_com/19259")
puzzle = Puzzle.from_file("online_nonograms_com/16624")

puzzle.solve
# puzzle.draw(rotate: false)
puzzle.draw(colour: false)
result = puzzle.solved? ? Rainbow(" ### Solved").green : Rainbow("### Not solved").red
puts "#{result} in #{Time.now.utc - start}s"
puts

# https://en.wikipedia.org/wiki/X11_color_names

# TODO: check ranges for lengths that match the clues and fill
