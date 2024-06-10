require "pry"
require "pry-remote"
require "pry-nav"

require "./clue_set_view"
require "./patches"
require "./puzzle"

class BoardView
  include Enumerable

  attr_reader :index, :is_row, :from

  def initialize(board, index, is_row, from, to)
    @board = board
    @index = index
    @is_row = is_row
    @from = from
    @to = to
  end

  def length
    @to - @from
  end

  def each
    (0...length).each do |i|
      yield(self[i])
    end
  end

  def []=(index, value)
    if @is_row
      @board[@index, @from + index] = value
    else
      @board[@from + index, @index] = value
    end
  end

  def [](index)
    raise "Out of bounds #{index} in [#{@from}, #{@to})" unless in_bounds?(index)

    if @is_row
      @board[@index, @from + index]
    else
      @board[@from + index, @index]
    end
  end

  def limit_colours(index, limits)
    if @is_row
      @board.limit_colours(@index, @from + index, limits)
    else
      @board.limit_colours(@from + index, @index, limits)
    end
  end

  def colour_limits(index)
    raise "Out of bounds #{index} in [#{@from}, #{@to})" unless in_bounds?(index)

    if @is_row
      @board.colour_limits(@index, @from + index)
    else
      @board.colour_limits(@from + index, @index)
    end
  end

  def colour_limits_include?(index, colour)
    limits = colour_limits(index)
    limits.nil? || limits.include?(colour)
  end

  def fill(from, to, colour)
    (from...to).each { self[_1] = colour }
  end

  def in_bounds?(index)
    index >= 0 && index < length
  end

  def dirty?
    @board.dirty?(@is_row, @index)
  end

  def clean
    @board.clean(@is_row, @index)
  end

  def solve
    @board.solve(@is_row, @index)
  end

  def padding
    left = nil
    right = nil
    index = 0
    while length > 0 && (left.nil? || right.nil?)
      rindex = length - index
      break if left.nil? && right.nil? && rindex < index

      left ||= index if self[index] != Puzzle::BLANK
      right ||= rindex if self[rindex - 1] != Puzzle::BLANK
      index += 1
    end
    left.nil? ? [0, 0] : [left, right]
  end

  def trim
    view(*padding)
  end

  def to_s(with_colours: false)
    cells = (0...length).map { |i| self[i].nil? ? Puzzle::UNKNOWN : self[i].to_s }.join
    if with_colours
      colours = (0...length).map { |i| self[i].nil? ? colour_limits(i).to_a.sort : [] }
      max_colour_length = colours.map(&:length).max
      colour_strings = (0...max_colour_length).map do |ci|
        colours.map { _1[ci] || " " }.join
      end.join("\n")
      [cells, colour_strings].join("\n")
    else
      cells
    end
  end

  def to_clues
    result = []
    previous = nil
    count = 0
    each_with_index do |current, i|
      if current == previous
        count += 1
      else
        if !previous.nil?
          result << Clue.new(count, previous, i - count)
        end
        count = 1
        previous = current
      end
    end

    result << Clue.new(count, previous, length - count) if !previous.nil?

    ClueSet.new(result)
  end

  def view(from, to = length)
    self.class.new(@board, @index, @is_row, @from + from, @from + to)
  end

  # Start is inclusive in both directions
  def find_range_of_first_fit(clue, start, right:)
    remaining = clue.count
    if right
      to = start
      # Find the ending index of the first place to the right where the clue could fit.
      loop do
        if self[to] == Puzzle::BLANK
          remaining = clue.count
        elsif !self[to].nil? && self[to] != clue.colour
          raise "Unable to find a place to fit the clue"
        else
          remaining -= 1
        end
        to += 1
        break if remaining == 0
      end
      from = to - clue.count
    else
      from = start
      # Find the starting index of the first place to the left where the clue could fit.
      loop do
        if self[from] == Puzzle::BLANK
          remaining = clue.count
        elsif !self[from].nil? && self[from] != clue.colour
          raise "Unable to find a place to fit the clue"
        else
          remaining -= 1
        end
        break if remaining == 0

        from -= 1
      end
      to = from + clue.count
    end
    (from...to)
  end

  def limit_colours_with_clue(clue, start, right:)
    return if clue.solved?

    find_range_of_first_fit(clue, start, right: right).each { limit_colours(_1, clue.colour) }
  end

  def fill_from_ranges(csv)
    ranges = csv.ranges(self)
    ranges = csv.limit_ranges_using_matches(ranges, self, csv.match_recursive(self))

    # Fill any singular clue range with the clue colour.
    ranges.each_with_index do |clue_ranges, index|
      next unless clue_ranges.one?

      clue = csv[index]
      range = clue_ranges.first
      next unless range.size < clue.count * 2

      fill(range.last - clue.count, range.first + clue.count, clue.colour)
    end

    # Fill any indexes missing from all of the ranges with blanks.
    coalesced_ranges = ClueSetView.coalesce_ranges(ranges.flatten)

    range_enum = coalesced_ranges.each

    range = range_enum.next
    each_with_index do |_, i|
      range = range_enum.next_or_nil if range && i >= range.last
      # binding.pry if (range.nil? || i < range.first) && self[i].nil?
      self[i] = Puzzle::BLANK if (range.nil? || i < range.first) && self[i].nil?
    end
  end

  def limit_edge_colours(csv)
    return if csv.colours.length <= 1

    limit_colours_with_clue(csv[0], 0, right: true)
    limit_colours_with_clue(csv[csv.length - 1], length - 1, right: false)
  end

  def fill_from_matches(csv, bfi: false)
    return if csv.empty?

    # TODO: there is potential information in the ranges, especially when there are spaces in the
    # board. Get the ranges separately here and fill spaces using that information.

    matches = bfi ? csv.match_bfi(self) : csv.match_recursive(self)

    board_clue_set = to_clues
    fill_in_between_matches(csv, board_clue_set, matches)
    fill_from_edges(csv, board_clue_set, matches)
    cap_solved_clues(csv, board_clue_set, matches)
    fill_around_blanks(csv, board_clue_set, matches)
    limit_colours_using_matches(csv, matches)
    limit_colours_to_unsolved(csv)
    fill_blanks_where_no_more_colours
    cap_identical_clues(csv)

    fill_from_ranges(csv)
  end

  # TODO: Could be useful to recursively call this method on the spaces between matches.
  def fill_in_between_matches(csv, board_clue_set, matches)
    return if matches.empty?

    # Fill before the first match
    board_clue_index, clue_index = matches.first
    board_clue = board_clue_set[board_clue_index]
    spacer = csv.spacer(clue_index, before: true)
    csv.view(0, 0, clue_index).fill(view(0, board_clue.solution - spacer).trim)

    # Fill between matches
    matches.each_cons(2) do |(left_board_i, left_clue_i), (right_board_i, right_clue_i)|
      left_board_clue = board_clue_set[left_board_i]
      right_board_clue = board_clue_set[right_board_i]

      if right_clue_i == left_clue_i
        # The board clues are the same clue. Fill the space between them.
        (left_board_clue.to...right_board_clue.solution).
          each { |i| self[i] = left_board_clue.colour }
      elsif right_clue_i - left_clue_i == 1
        # The clues are adjacent, so extrapolate from them.
        right_clue = csv[right_clue_i]
        left_clue = csv[left_clue_i]

        spacer = csv.spacer(left_clue_i, before: false)

        from = right_board_clue.solution - spacer - left_clue.count
        to = left_board_clue.solution
        (from...to).each { |i| self[i] = left_board_clue.colour }

        from = right_board_clue.to
        to = left_board_clue.to + spacer + right_clue.count
        (from...to).each { |i| self[i] = right_board_clue.colour }

        # Also, fill with spaces between clues.
        from = left_board_clue.solution + spacer + left_clue.count
        to = right_board_clue.to - spacer - right_clue.count
        (from...to).each { |i| self[i] = Puzzle::BLANK }
      else
        left_spacer = csv.spacer(left_clue_i, before: false)
        right_spacer = csv.spacer(right_clue_i, before: true)

        sub_bv = view(left_board_clue.to + left_spacer, right_board_clue.solution - right_spacer).
          trim
        sub_csv = csv.view(left_board_clue.to, left_clue_i + 1, right_clue_i)
        sub_csv.fill(sub_bv)

        sub_bv.cap_identical_clues(sub_csv)
      end
    end

    # Fill after the last match
    board_clue_index = matches.keys.last
    clue_index = matches[board_clue_index]
    board_clue = board_clue_set[board_clue_index]
    spacer = csv.spacer(clue_index, before: false)
    csv.view(board_clue.to, clue_index + 1).fill(view(board_clue.to + spacer).trim)
  end

  def fill_from_edges(csv, board_clue_set, matches)
    return if matches.empty?

    bcsv = board_clue_set.view
    matches.each do |(board_clue_index, clue_index)|
      board_clue = board_clue_set[board_clue_index]
      clue = csv[clue_index]

      left_limit = bcsv.limit(board_clue_index, length, before: true)
      if left_limit
        (board_clue.to...left_limit + clue.count).each { |i| self[i] = clue.colour }
      end

      right_limit = bcsv.limit(board_clue_index, length, before: false)
      if right_limit
        (right_limit - clue.count...board_clue.solution).each { |i| self[i] = clue.colour }
      end
    end

    # Fill blanks from the edges
    board_clue_index, clue_index = matches.first
    if clue_index == 0
      board_clue = board_clue_set[board_clue_index]
      clue = csv[clue_index]
      (0...board_clue.to - clue.count).each { |i| self[i] = Puzzle::BLANK }
    end

    board_clue_index = matches.keys.last
    clue_index = matches[board_clue_index]
    if clue_index == csv.length - 1
      board_clue = board_clue_set[board_clue_index]
      clue = csv[clue_index]
      (board_clue.solution + clue.count...length).each { |i| self[i] = Puzzle::BLANK }
    end
  end

  def cap_solved_clues(csv, board_clue_set, matches)
    matches.each do |board_clue_index, clue_index|
      board_clue = board_clue_set[board_clue_index]
      next unless board_clue.count == csv[clue_index].count

      if clue_index > 0 && csv[clue_index - 1].colour == board_clue.colour
        self[board_clue.solution - 1] = Puzzle::BLANK
      end

      if clue_index < csv.length - 1 && csv[clue_index + 1].colour == board_clue.colour
        self[board_clue.to] = Puzzle::BLANK
      end
    end
  end

  def cap_identical_clues(csv)
    # If all of the clues are the same colour and count, cap any board clues that match them.
    clues = csv.uniq { [_1.count, _1.colour] }
    if clues.one?
      clue = clues.first
      to_clues.select { _1.count == clue.count && _1.colour == clue.colour }.each do |bvc|
        self[bvc.solution - 1] = Puzzle::BLANK if bvc.solution > 0
        self[bvc.to] = Puzzle::BLANK if bvc.to < length
      end
    end
  end

  # Fills cells where spaces are between consecutive clues
  def fill_around_blanks(csv, board_clue_set, matches)
    board_clue_set.each_with_index do |board_clue, index|
      next unless board_clue.colour == Puzzle::BLANK
      next unless matches[index - 1]
      next unless matches[index + 1]
      next unless matches[index - 1] == matches[index + 1] - 1 # Ensure consecutive clues.

      # Check the clue on the left.
      left = board_clue_set[index - 1]
      clue = csv[matches[index - 1]]

      # Extend the left match
      fill(board_clue.solution - clue.count, left.solution, left.colour)
      # Extend the spaces leftward
      fill(left.solution + clue.count, board_clue.solution, Puzzle::BLANK)

      # Check the clue on the right.
      right = board_clue_set[index + 1]
      clue = csv[matches[index + 1]]

      # Extend the right match
      fill(right.solution, board_clue.to + clue.count, right.colour)
      # Extend the spaces rightward
      fill(board_clue.to, right.to - clue.count, Puzzle::BLANK)
    end
  end

  # Uses matches to know what limits there are in the colours extending from them.
  def limit_colours_using_matches(csv, matches)
    # Find matches where there are unmatched clues on either side.
    matches.each_value do |clue_index|
      clue = csv[clue_index]
      next unless clue.solved?

      if clue_index > 0
        left_clue = csv[clue_index - 1]
        start = clue.solution - (clue.colour == left_clue.colour ? 1 : 0) - 1
        limit_colours_with_clue(left_clue, start, right: false)
      end

      next unless clue_index + 1 < csv.length

      right_clue = csv[clue_index + 1]
      start = clue.to + (clue.colour == right_clue.colour ? 1 : 0)
      limit_colours_with_clue(right_clue, start, right: true)
    end
  end

  # Limit the colours of unsolved cells to the colours of the remaining unsolved clues.
  def limit_colours_to_unsolved(csv)
    colours = csv.unsolved_colours
    each_with_index { |_, i| limit_colours(i, colours) if self[i].nil? }
  end

  def fill_blanks_where_no_more_colours
    each_with_index do |_, i|
      self[i] = Puzzle::BLANK if self[i].nil? && colour_limits(i).empty?
    end
  end

  #
  # Experimental
  #
  def clue_ranges(csv)
    clue_ranges_using_solved(csv)
  end

  def clue_ranges_using_solved(csv)
    solved_index = csv.find_index(&:solved?)
    if solved_index
      # If any in the clue set are solved, split on that an recurse on either side.
      clue = csv[solved_index]

      # Left side
      left_ranges = if solved_index > 0
        spacer = csv.spacer(solved_index, before: true)
        sub_bv = view(0, clue.solution - spacer)
        sub_csv = csv.view(0, 0, solved_index)
        sub_bv.clue_ranges_using_solved(sub_csv)
      end || []

      # Right side
      right_ranges = if solved_index < csv.length - 1
        spacer = csv.spacer(solved_index, before: false)
        sub_bv = view(clue.to + spacer, length)
        sub_csv = csv.view(clue.to + spacer, solved_index + 1, csv.length)
        sub_bv.clue_ranges_using_solved(sub_csv)
      end || []

      # TODO: Translate ranges back to the current view.
      # [*left_ranges, (clue.solution...clue.to), *right_ranges]
      return
    end

    clue_ranges_using_solution_matching(csv)
  end

  def clue_ranges_using_solution_matching(csv)
    raise if csv.empty?

    bvcs = to_clues
    if bvcs.length > 1
      binding.pry
      solution_clue_indexes = Array.new(bvcs.length)

      # => "[2g(1),1b(4),3g(5),1g(10),2b(12),3 (18),1 (24)]"
      # => "[1b,3g,1b,3g,2b,2g,6b]"

      #                   2g(1) 1b(4) 3g(5)        1g(10) 2b(12) 3 (18) 1 (24)
      #
      #             1b    3g    1b    3g     2b    2g     6b



      # => ".gg.bggg..g.bb....   ... ............"
    end

    binding.pry

    # TODO compute generic ranges



    # max_first_location = board_view.length - sum

    # # freedom = board_view.length - sum + 1
    # # clues = length
    # # puts "freedom: #{freedom}, clues: #{clues}, complexity: #{freedom**clues}"
    # iterations = 0

    # solutions = []
    # locations = []
    # move_last_clue = false
    # loop do
    #   iterations += 1
    #   puts "BFI find aborted" if iterations == 1_000_000
    #   break if iterations >= 1_000_000

    #   if move_last_clue
    #     # Increment the current location
    #     locations[-1] += 1
    #     clue_index = locations.length - 1

    #     # Short curcuit
    #     break if clue_index.zero? && locations[-1] > max_first_location

    #     clue = self[clue_index]
    #   else
    #     clue_index = locations.length
    #     clue = self[clue_index]

    #     # Find the first valid location for the clue
    #     previous_clue = clue_index.zero? ? nil : self[clue_index - 1]
    #     location = previous_clue.nil? ? 0 : locations[-1] + previous_clue.count
    #     location += 1 if clue.colour == previous_clue&.colour
    #     locations << location
    #   end

    #   location = locations[-1]
    #   while location + clue.count <= board_view.length
    #     break if clue.valid_location_bfi?(board_view, location)

    #     location += 1
    #   end

    #   if location + clue.count <= board_view.length
    #     locations[-1] = location

    #     if locations.length == length
    #       # Make sure that the spaces in between the clues don't contain any solved cells.
    #       valid = (0..length).all? do |i|
    #         from = i.zero? ? 0 : locations[i - 1] + self[i - 1].count
    #         to = i == length ? board_view.length : locations[i]
    #         (from...to).all? { |l| board_view[l].nil? || board_view[l] == Puzzle::BLANK }
    #       end

    #       solutions << locations.dup if valid
    #       move_last_clue = true
    #     else
    #       move_last_clue = false
    #     end
    #   else
    #     break if clue_index.zero?

    #     move_last_clue = true
    #     locations.pop
    #   end
    # end

    # # puts "Find iterations: #{iterations}"

    # solutions

    #
    #
    #
    #
    #
    #

    # # Find the clue colour with the least instances. This makes it easier to find matches.
    # colour = csv.group_by(&:colour).transform_values(&:length).min_by(&:last).first

    # # Split the board into ranges in which the colour can go
    # colour_ranges = []
    # from = nil
    # each_with_index do |c, i|
    #   if c.nil? || c == colour
    #     from = i if from.nil?
    #   elsif from
    #     colour_ranges << (from...i)
    #     from = nil
    #   end
    # end
    # colour_ranges << (from...length) if from

    # bvcs = to_clues.select { _1.colour == colour }
    # colour_clues = csv.select { _1.colour == colour }
    # # => "[2g(1),3g(5),1g(10)]"
    # # => [0...4, 5...12, 14...18, 21...24, 25...37]
    # # =>  .gg.   ggg..g. ....     ...      ............"
    # # <ClueView:0x000000010d1f8ca0 @clue=#<Clue:0x000000010ceef3b0 @colour=:g, @count=3, @solution=nil>, @offset=8>,
    # # <ClueView:0x000000010d1f8c00 @clue=#<Clue:0x000000010ceeeac8 @colour=:g, @count=3, @solution=nil>, @offset=8>,
    # # <ClueView:0x000000010d1f8b60 @clue=#<Clue:0x000000010ceee7f8 @colour=:g, @count=2, @solution=nil>, @offset=8>]

    # # 1b,1b,2b,6b
    # # 3g,3g,2g

    # # => "[1b,3g,1b,3g,2b,2g,6b]"
    # # => ".gg.bggg..g.bb....   ... ............"

    # binding.pry
  end
end
