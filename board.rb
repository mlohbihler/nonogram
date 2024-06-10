require "rainbow"

require "./puzzle"

class Board
  attr_reader :row_count, :col_count

  def initialize(row_count, col_count, solution = nil)
    @board = Array.new(row_count) { Array.new(col_count) }
    @colour_limits = Array.new(row_count) { Array.new(col_count) }
    @dirty_rows = Array.new(row_count) { true }
    @dirty_cols = Array.new(col_count) { true }
    @row_count = row_count
    @col_count = col_count
    @solution = solution
  end

  def self.from_strings(strs)
    cols = strs.first.length
    raise "All rows must have the same number of columns" if strs.any? { |r| r.length != cols }

    board = Board.new(strs.length, cols)
    strs.each_with_index do |str, r|
      str.chars.each_with_index { |e, c| board[r, c] = e.to_sym if e != Puzzle::UNKNOWN }
    end
    board
  end

  def init_colour_limits(top_clue_sets, left_clue_sets)
    # Fill with the left clue colours
    @colour_limits.each_with_index do |row, row_index|
      row.fill(left_clue_sets[row_index].colours)
    end

    # Intersect with the top clue colours
    top_clue_sets.each_with_index do |cs, col_index|
      col_limits = cs.colours
      @colour_limits.each do |row|
        row[col_index] = row[col_index] & col_limits
      end
    end
  end

  def view(index, is_row, from = 0, to = length(!is_row))
    BoardView.new(self, index, is_row, from, to)
  end

  def []=(row, col, value)
    if @board[row][col].nil?
      @dirty_rows[row] = true
      @dirty_cols[col] = true
    elsif @board[row][col] != value
      raise "Trying to set (#{row},#{col}) to '#{value}' when it is already '#{@board[row][col]}'"
    end
    if @solution && @solution[row][col] != value
      raise "solution value to set #{value} does not match puzzle solution #{@solution[row][col]}"
    end
    unless value == Puzzle::BLANK || @colour_limits[row][col].nil? ||
        @colour_limits[row][col].include?(value)
      raise "Trying to set (#{row},#{col}) to '#{value}' which is not in allowed colours '#{@colour_limits[row][col]}'"
    end

    @board[row][col] = value
  end

  def [](row, col)
    @board[row][col]
  end

  def limit_colours(row, col, limits)
    limits = [limits] if limits.is_a?(Symbol)
    limits = limits.to_set

    # For testing
    @colour_limits[row][col] = limits.dup if @colour_limits[row][col].nil?

    unless self[row, col].nil? || limits.include?(self[row, col])
      raise <<~MSG
        Limiting the colours of a solved cell (#{row},#{col}):
        present value '#{self[row, col]}', colour limits: #{limits}
      MSG
    end
    unless @solution.nil? || @solution[row][col] == Puzzle::BLANK ||
        limits.include?(@solution[row][col])
      raise "puzzle solution #{@solution[row][col]} not in colour limits #{limits} at (#{row}, #{col})"
    end

    new_limits = @colour_limits[row][col] & limits
    if @colour_limits[row][col] != new_limits
      @dirty_rows[row] = true
      @dirty_cols[col] = true
    end

    @colour_limits[row][col] = new_limits
  end

  def colour_limits(row, col)
    @colour_limits[row][col]
  end

  def colour_limits_include?(row, col, colour)
    return true if @colour_limits[row][col].nil?

    @colour_limits[row][col].include?(colour)
  end

  def dirtify
    # TODO only need to dirtify the rows that are not solved.
    @dirty_rows.fill(true)
    @dirty_cols.fill(true)
  end

  def any_dirty?
    @dirty_rows.any? || @dirty_cols.any?
  end

  def dirty?(is_row, index)
    is_row ? @dirty_rows[index] : @dirty_cols[index]
  end

  def length(is_row)
    is_row ? @row_count : @col_count
  end

  def clean(is_row, index)
    _update_dirty(is_row, index, false)
  end

  def solve(is_row, index)
    _update_dirty(is_row, index, nil)
  end

  def solved?
    @dirty_rows.all?(&:nil?) || @dirty_cols.all?(&:nil?)
  end

  def _update_dirty(is_row, index, value)
    if is_row
      @dirty_rows[index] = value
    else
      @dirty_cols[index] = value
    end
  end
end
