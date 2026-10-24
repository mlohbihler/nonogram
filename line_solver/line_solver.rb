require "json"

# Exhaustive line solver for coloured nonograms, independent of the main solver. A Ruby port of
# solve.py using the same algorithm.
#
# Usage (from the project root):
#   ruby line_solver/line_solver.rb puzzles/paris.80x80.json [--drop-scan]
#
# Each row/column is solved with a DP over every placement of its clues, keeping only the values
# that some placement allows. This is repeated until nothing changes, then any remaining cells are
# resolved by backtracking. Every line deduction is sound, so a contradiction during propagation
# proves the clues are inconsistent. --drop-scan then lists lines whose removal makes the rest
# consistent, which are the typo candidates.
#
# Cells are bitmasks of the values they can still take: bit 0 is blank, bit i is values[i].
module LineSolver
  BLANK = " ".freeze

  class Puzzle
    attr_reader :rows, :cols, :values

    def self.from_file(path)
      top, left, colours = JSON.parse(File.read(path))
      new(top, left, colours.keys)
    end

    def initialize(top_clues, left_clues, colour_codes)
      @values = [BLANK, *(colour_codes - [BLANK]).sort]
      @cols = top_clues.map { parse(_1) }
      @rows = left_clues.map { parse(_1) }
    end

    def all_values
      (1 << @values.length) - 1
    end

    def fresh_grid
      Array.new(@rows.length) { Array.new(@cols.length, all_values) }
    end

    def known(grid)
      grid.sum { |row| row.count { single?(_1) } }
    end

    def single?(cell)
      cell & (cell - 1) == 0
    end

    def value(cell)
      @values[cell.bit_length - 1]
    end

    private

    # "3b,2r" => [[3, bit of b], [2, bit of r]]
    def parse(clue_string)
      clue_string.scan(/(\d+)(\w)/).map { |count, colour| [count.to_i, @values.index(colour)] }
    end
  end

  # Narrows one line. Returns the new cells, or nil if no placement of the clues fits.
  class Line
    def self.solve(clues, cells)
      new(clues, cells).solve
    end

    def initialize(clues, cells)
      @clues = clues
      @cells = cells
      @n = cells.length
      @k = clues.length
      @feasible = {}
      @place = {}
    end

    def solve
      return nil unless feasible?(0, 0)

      # Walk every state reachable from the start that can still finish, recording the values used.
      possible = Array.new(@n, 0)
      seen = { [0, 0] => true }
      stack = [[0, 0]]
      until stack.empty?
        i, j = stack.pop
        next if i == @n

        if blank_allowed?(i) && feasible?(i + 1, j)
          possible[i] |= 1
          push(seen, stack, [i + 1, j])
        end

        nxt = place(i, j)
        next unless nxt && feasible?(*nxt)

        count, colour = @clues[j]
        (i...i + count).each { possible[_1] |= 1 << colour }
        possible[i + count] |= 1 if nxt[0] > i + count
        push(seen, stack, nxt)
      end

      @cells.each_with_index.map { |cell, x| cell & possible[x] }
    end

    private

    def push(seen, stack, state)
      return if seen[state]

      seen[state] = true
      stack << state
    end

    def blank_allowed?(i)
      @cells[i] & 1 != 0
    end

    def feasible?(i, j)
      key = i * (@k + 1) + j
      return @feasible[key] if @feasible.key?(key)

      @feasible[key] =
        if i == @n
          j == @k
        elsif blank_allowed?(i) && feasible?(i + 1, j)
          true
        else
          nxt = place(i, j)
          !nxt.nil? && feasible?(*nxt)
        end
    end

    # The state after placing clue j starting at i, or nil if it doesn't fit.
    def place(i, j)
      key = i * (@k + 1) + j
      return @place[key] if @place.key?(key)

      @place[key] = begin
        if j == @k
          nil
        else
          count, colour = @clues[j]
          bit = 1 << colour
          if i + count > @n || (i...i + count).any? { @cells[_1] & bit == 0 }
            nil
          else
            nxt = i + count
            # Consecutive clues of the same colour need a blank between them.
            if j + 1 < @k && @clues[j + 1][1] == colour
              nxt < @n && blank_allowed?(nxt) ? [nxt + 1, j + 1] : nil
            else
              [nxt, j + 1]
            end
          end
        end
      end
    end
  end

  # Narrows grid in place. Returns the first contradictory line as [kind, index], or nil.
  def self.propagate(puzzle, grid, skip: nil)
    rows = puzzle.rows
    cols = puzzle.cols
    dirty = (0...rows.length).map { [:row, _1] } + (0...cols.length).map { [:col, _1] }
    queued = dirty.to_h { [_1, true] }

    until dirty.empty?
      line_id = dirty.pop
      queued.delete(line_id)
      next if line_id == skip

      kind, idx = line_id
      line = kind == :row ? grid[idx].dup : grid.map { _1[idx] }
      new = Line.solve(kind == :row ? rows[idx] : cols[idx], line)
      return line_id if new.nil?

      new.each_with_index do |cell, x|
        next if cell == line[x]

        r, c = kind == :row ? [idx, x] : [x, idx]
        grid[r][c] = cell
        other = kind == :row ? [:col, c] : [:row, r]
        next if queued[other]

        queued[other] = true
        dirty << other
      end
    end
    nil
  end

  # Returns up to `limit` solutions as grids of values.
  def self.search(puzzle, grid, limit: 2, budget: [20_000])
    return [] unless propagate(puzzle, grid).nil?

    undecided = []
    grid.each_with_index do |row, r|
      row.each_with_index { |cell, c| undecided << [cell.digits(2).sum, r, c] unless puzzle.single?(cell) }
    end
    return [grid.map { |row| row.map { puzzle.value(_1) } }] if undecided.empty?

    budget[0] -= 1
    raise "search budget exhausted" if budget[0] < 0

    _, r, c = undecided.min
    solutions = []
    (0...puzzle.values.length).each do |bit|
      next if grid[r][c] & (1 << bit) == 0

      guess = grid.map(&:dup)
      guess[r][c] = 1 << bit
      solutions += search(puzzle, guess, limit: limit - solutions.length, budget: budget)
      break if solutions.length >= limit
    end
    solutions
  end

  def self.line_name(kind, idx)
    "#{kind} #{idx + 1}"
  end

  def self.main(argv)
    puzzle = Puzzle.from_file(argv[0])
    rows = puzzle.rows
    cols = puzzle.cols
    puts "#{rows.length} rows x #{cols.length} cols, colours #{puzzle.values - [BLANK]}"

    grid = puzzle.fresh_grid
    bad = propagate(puzzle, grid)
    unless bad.nil?
      puts "Line propagation: CONTRADICTION (first detected on #{line_name(*bad)})"
      if argv.include?("--drop-scan")
        puts "Lines whose removal makes the rest consistent (typo candidates):"
        { row: rows, col: cols }.each do |kind, clue_sets|
          clue_sets.each_with_index do |clues, idx|
            next unless propagate(puzzle, puzzle.fresh_grid, skip: [kind, idx]).nil?

            puts "  #{line_name(kind, idx)}: #{clues.map { |n, c| "#{n}#{puzzle.values[c]}" }.join(',')}"
          end
        end
      end
      exit 1
    end

    puts "Line propagation: consistent, #{puzzle.known(grid)}/#{rows.length * cols.length} cells determined"
    solutions = search(puzzle, grid)
    if solutions.empty?
      puts "Search: NO solution exists"
      exit 1
    end
    puts solutions.one? ? "Search: unique solution" : "Search: multiple solutions"
    solutions.first.each { |row| puts row.map { _1 == BLANK ? "." : _1 }.join }
  end
end

LineSolver.main(ARGV) if __FILE__ == $PROGRAM_NAME
