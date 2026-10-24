require "json"

# Runs the main solver and the line solver on each puzzle in the same process and compares them.
#
# Usage (from the project root):
#   bundle exec ruby --yjit line_solver/compare.rb [puzzle names...]
#
# Puzzle names are paths under puzzles/ without .json; all puzzles are run if none are given.
# Times exclude startup and file loading.

%w[board board_view clue clue_set clue_set_view puzzle].each { require_relative "../#{_1}" }
require_relative "line_solver"

def time
  start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  result = yield
  [result, Process.clock_gettime(Process::CLOCK_MONOTONIC) - start]
end

def main_solver(name)
  puzzle = Puzzle.from_file(name)
  _, seconds = time { puzzle.solve }
  cells = puzzle.instance_variable_get(:@board).instance_variable_get(:@board).flatten
  known = 100.0 * cells.count { !_1.nil? } / cells.size
  [puzzle.solved? ? "solved" : format("%.1f%%", known), seconds]
rescue StandardError => e
  ["error (#{e.class})", nil]
end

def line_solver(name)
  puzzle = LineSolver::Puzzle.from_file("puzzles/#{name}.json")
  grid = puzzle.fresh_grid
  bad, line_seconds = time { LineSolver.propagate(puzzle, grid) }
  return ["contradiction", line_seconds, nil] unless bad.nil?

  total = puzzle.rows.length * puzzle.cols.length
  line_result = puzzle.known(grid) == total ? "solved" : format("%.1f%%", 100.0 * puzzle.known(grid) / total)
  solutions, search_seconds = time { LineSolver.search(puzzle, grid) }
  search_result = solutions.one? ? "unique" : "#{solutions.length} solutions"
  [line_result, line_seconds, [search_result, line_seconds + search_seconds]]
end

Dir.chdir(File.expand_path("..", __dir__))
names = ARGV.empty? ? Dir["puzzles/**/*.json"].sort.map { _1.delete_prefix("puzzles/").delete_suffix(".json") } : ARGV

seconds = ->(s) { s ? format("%6.2fs", s) : "      " }
puts format("%-28s %-8s | %-14s %s | %-14s %s | %-12s %s", "puzzle", "size", "main solver", "  time ",
  "line logic", "  time ", "+ search", "  time ")
names.each do |name|
  main_result, main_seconds = main_solver(name)
  line_result, line_seconds, (search_result, search_seconds) = line_solver(name)
  size = name[/\d+x\d+/] || begin
    top, left = JSON.parse(File.read("puzzles/#{name}.json"))
    "#{top.length}x#{left.length}"
  end
  puts format("%-28s %-8s | %-14s %s | %-14s %s | %-12s %s", name, size, main_result, seconds.(main_seconds),
    line_result, seconds.(line_seconds), search_result || "", seconds.(search_seconds))
end
