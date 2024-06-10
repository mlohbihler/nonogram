class Puzzle
  BLANK = :" "
  UNKNOWN = ".".freeze
  FANCY_UNKNOWN = "\u00b7".freeze

  def self.from_file(name)
    data = JSON.parse(File.read("puzzles/#{name}.json"))
    new(*data)
  end

  def initialize(top_clue_sets, left_clue_sets, colour_definitions, solution = nil)
    @top_clue_sets = top_clue_sets.map { |cs| ClueSet.new(cs) }
    @left_clue_sets = left_clue_sets.map { |cs| ClueSet.new(cs) }
    @colour_definitions = colour_definitions.transform_keys(&:to_sym).transform_values(&:to_sym)
    @board = Board.new(@left_clue_sets.length, @top_clue_sets.length, parse_solution(solution))
    @board.init_colour_limits(@top_clue_sets, @left_clue_sets)

    # Validations:
    # The counts for each colour are the same for the rows and cols.
    counter = lambda do |clue_sets|
      counts = Hash.new(0)
      clue_sets.each { |cs| cs.each { |c| counts[c.colour] += c.count } }
      raise "Clues cannot contain the default colour" if counts.key(BLANK)

      counts
    end

    top = counter.call(@top_clue_sets)
    left = counter.call(@left_clue_sets)
    raise "Top and left counts do not match: #{top} vs #{left}" if top != left

    # The sums of any rows are not greater than the number of cols and vice versa
    @top_clue_sets.each.with_index do |cs, i|
      len = ClueSetView.new(cs).sum
      max = @board.row_count
      raise "Top clue set #{i + 1} is too long: #{len} vs #{max}" if len > max
    end
    @left_clue_sets.each.with_index do |cs, i|
      len = ClueSetView.new(cs).sum
      max = @board.col_count
      raise "Left clue set #{i + 1} is too long: #{len} vs #{max}" if len > max
    end

    # Blank is defined
    raise "No default colour defined" if @colour_definitions[BLANK].nil?

    # Colour codes must be a single character
    if colour_definitions.keys.any? { |e| e.length != 1 }
      raise "Colour codes must be a single character"
    end

    # All colours are in the definitions, and vice versa
    if (@colour_definitions.keys - [BLANK]).sort != top.keys.sort
      raise "Colour codes do not match clues: #{@colour_definitions.keys} vs #{top.keys}"
    end
  end

  def parse_solution(solution_strings)
    return if solution_strings.nil?

    if solution_strings.length != @left_clue_sets.length
      raise "Solution rows (#{solution_strings.length}) is different from the row count (#{@left_clue_sets.length})"
    end

    solution_strings.map do |str|
      if str.length != @top_clue_sets.length
        raise "Solution string length (#{str.length}) is different from the col count (#{@right_clue_sets.length})"
      end

      str.chars.map do |c|
        colour = c.to_sym
        if colour != Puzzle::BLANK && !@colour_definitions.key?(colour)
          raise "Solution colour #{c} is not in colour defintions"
        end

        colour
      end
    end
  end

  def for_all_clue_sets
    fn = lambda do |clue_sets, is_rows|
      clue_sets.each_with_index do |cs, index|
        bv = BoardView.new(@board, index, is_rows, 0, @board.length(!is_rows))
        yield(cs, bv)
      end
    end
    fn.call(@left_clue_sets, true)
    fn.call(@top_clue_sets, false)
  end

  def iterate(until_clean:)
    @board.dirtify

    loop do
      for_all_clue_sets do |cs, bv|
        next unless bv.dirty?

        bv.clean
        yield(cs, bv)

        bv.solve if cs.solved?
        # draw
        # binding.pry
      end

      break if !until_clean
      break unless @board.any_dirty?
    end
  end

  def solve
    # Fill any row/cols without clues with spaces.
    for_all_clue_sets do |cs, bv|
      (0...bv.length).each { |i| bv[i] = Puzzle::BLANK } if cs.empty?
    end

    # Start with a easy method of adding initial information. Then we can move on to move intricate
    # algos.
    fill_rows_by_counting

    # Like this one.
    fill_rows_by_clue_matching

    binding.pry
    # iterate(until_clean: false) do |cs, bv|
    #   csv = cs.view
    #   ranges = csv.ranges(bv)

    #   csv.zip(ranges).each do |(clue, clue_ranges)|
    #     next if clue.solved?
    #     next unless clue_ranges.one?
    #     next unless clue.count * 2 > clue_ranges.first.size

    #     binding.pry
    #     # board_view.fill(clue_ranges.first.first, clue_ranges.first.last, clue.colour)
    #   end
    # end
  end

  def solved?
    @board.solved?
  end

  def fill_rows_by_counting
    # Fills cells by trying to match clues to existing board values, and then creating views of
    # corresponding rows/cols and clues, and using the fill method to try and find more values.
    iterate(until_clean: false) do |cs, bv|
      cs.view.fill(bv)
    end
  end

  def fill_rows_by_clue_matching
    @board.dirtify

    iterate(until_clean: true) do |cs, bv|
      csv = cs.view
      bv.limit_edge_colours(csv)
      bv.fill_from_matches(csv)
      # @board.draw
      # binding.pry
    end
  end

  def fill_rows_by_clue_matching_bfi
    @board.dirtify

    iterate(until_clean: false) do |cs, bv|
      # binding.pry
      bv.fill_from_matches(cs.view, bfi: true)
      # @board.draw
      # binding.pry
    end
  end

  #
  # Drawing
  #
  def draw(colour: false, rotate: false)
    colour && @colour_definitions ? draw_with_colour : draw_without_colour(rotate: rotate)
  end

  def draw_without_colour(rotate: false)
    if rotate
      col_range = (0...@left_clue_sets.length)
      row_range = (@top_clue_sets.length - 1..0).step(-1)
      is_row = false
      clues = @top_clue_sets
    else
      col_range = (0...@top_clue_sets.length)
      row_range = (0...@left_clue_sets.length)
      is_row = true
      clues = @left_clue_sets
    end

    puts "  #{col_range.map { (_1 + 1) % 10 }.join}"
    puts "  #{'-' * col_range.size}"

    row_range.each do |row|
      board = col_range.map do |col|
        (is_row ? @board[row, col] : @board[col, row]) || Puzzle::FANCY_UNKNOWN
      end.join
      dirty = dirty_render(@board.dirty?(is_row, row))
      puts "#{(row + 1) % 10}|#{board}|#{dirty} #{clues[row]}"
    end

    puts "  #{col_range.map { dirty_render(@board.dirty?(!is_row, _1)) }.join}"
  end

  def draw_with_colour
    indices = (0...@top_clue_sets.length).map do |i|
      s = ((i + 1) % 100).to_s.rjust(2)
      i.even? ? s : Rainbow(s).orchid
    end.join

    puts "   #{indices}"
    puts "   #{'-' * @top_clue_sets.length * 2}"

    (0...@left_clue_sets.length).each do |row|
      row_str = (0...@top_clue_sets.length).map do |col|
        e = @board[row, col]
        if e.nil?
          " #{Puzzle::FANCY_UNKNOWN}"
        elsif @colour_definitions && @colour_definitions[e]
          Rainbow("  ").bg(@colour_definitions[e])
        else
          e.to_s * 2
        end
      end.join

      index = ((row + 1) % 100).to_s.rjust(2)
      dirty = dirty_render(@board.dirty?(true, row))

      puts "#{row.even? ? index : Rainbow(index).orchid}|#{row_str}#{dirty}"
    end
    puts "   #{(0...@top_clue_sets.length).map { " #{dirty_render(@board.dirty?(false, _1))}" }.join}"
  end

  def dirty_render(value)
    return Rainbow("✓").green if value.nil?

    value ? Rainbow("X").darkorchid : " "
  end
end
