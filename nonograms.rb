require "json"
require "pry"
require "rainbow"

require "./board"
require "./board_view"
require "./clue"
require "./clue_set"
require "./clue_set_view"
require "./puzzle"

# Solves a puzzle and draws the result.
#
# Usage: bundle exec ruby --yjit nonograms.rb <puzzle> [--colour] [--rotate]
#
# <puzzle> is a name under puzzles/ without .json (e.g. online_nonograms_com/111636), or a path to
# the puzzle file. --colour draws the solution in its colours, --rotate draws it turned sideways.
class Nonograms
  USAGE = "Usage: bundle exec ruby --yjit nonograms.rb <puzzle> [--colour] [--rotate]".freeze

  def self.run(argv)
    names = argv.reject { _1.start_with?("--") }
    abort USAGE unless names.one?

    new(names.first).solve(colour: argv.include?("--colour"), rotate: argv.include?("--rotate"))
  end

  def initialize(puzzle)
    @name = puzzle.delete_prefix("puzzles/").delete_suffix(".json")
  end

  def solve(colour: false, rotate: false)
    start = Time.now.utc
    puzzle = Puzzle.from_file(@name)
    puzzle.solve
    seconds = Time.now.utc - start

    puzzle.draw(colour: colour, rotate: rotate)
    result = puzzle.solved? ? Rainbow("### Solved").green : Rainbow("### Not solved").red
    puts "#{result} #{@name}#{" (#{puzzle.title})" if puzzle.title} in #{seconds}s"
    puts
    puzzle.solved?
  end
end

exit(Nonograms.run(ARGV) ? 0 : 1) if __FILE__ == $PROGRAM_NAME
