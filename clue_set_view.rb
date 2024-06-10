require "./clue_view"
require "./patches"
require "./puzzle"

class ClueSetView
  include Enumerable

  def initialize(clue_set, board_offset = 0, from: 0, to: clue_set.length)
    @clue_set = clue_set
    @board_offset = board_offset
    @from = from
    @to = to
  end

  def each
    (@from...@to).each do |i|
      yield(self[i - @from])
    end
  end

  def length
    @to - @from
  end

  def empty?
    length == 0
  end

  def [](index)
    raise "Out of bounds #{index} in [#{@from}, #{@to})" unless in_bounds?(index)

    c = @clue_set[@from + index]
    @board_offset == 0 ? c : ClueView.new(c, @board_offset)
  end

  def in_bounds?(index)
    index >= 0 && index < length
  end

  def view(board_offset, from, to = length)
    self.class.new(@clue_set, @board_offset + board_offset, from: @from + from, to: @from + to)
  end

  def spacer(index, before:)
    if before
      if index == 0
        0
      else
        self[index - 1].colour == self[index].colour ? 1 : 0
      end
    elsif index == length - 1
      0
    else
      self[index + 1].colour == self[index].colour ? 1 : 0
    end
  end

  def limit(index, len, before:)
    if before
      if index == 0
        0
      else
        c = self[index - 1]
        c.colour == self[index].colour ? nil : c.to
      end
    elsif index == length - 1
      len
    else
      c = self[index + 1]
      c.colour == self[index].colour ? nil : c.solution
    end
  end

  # Calculates the minimum length of all of the clues in this view.
  def sum
    last_clue_colour = nil
    sum = 0
    each do |c|
      spacer = c.colour == last_clue_colour ? 1 : 0
      last_clue_colour = c.colour
      sum += c.count + spacer
    end
    sum
  end

  def ranges(bv)
    ranges = create_ranges(bv)

    loop do
      og_ranges = ranges.dup

      ranges = limit_range_overlap(ranges)
      ranges = remove_invalid_ranges(bv, ranges)
      # This doesn't work because the sub-view being worked on might not include all of the clues.
      # limit_colours_using_ranges(bv, ranges)

      break if og_ranges == ranges
    end

    ranges
  end

  def colours
    Set.new(map(&:colour).uniq)
  end

  def unsolved_colours
    Set.new(reject(&:solved?).map(&:colour).uniq)
  end

  # TODO: need a way to better accomodate for spaces in determining ranges. Like eliminating clue
  # ranges when they can't fit together inside a view section.
  def create_ranges(board_view)
    diff = board_view.length - sum
    padding = board_view.padding
    diff -= padding.first + board_view.length - padding.last
    offset = padding.first
    last_clue_colour = nil

    map do |clue|
      offset += 1 if clue.colour == last_clue_colour
      range = if clue.solved?
        (clue.solution...clue.to)
      else
        (offset...offset + clue.count + diff)
      end
      offset += clue.count
      last_clue_colour = clue.colour
      range
    end.map.with_index do |range, clue_index|
      # Split ranges by removing locations that contain incompatible solutions.
      clue = self[clue_index]
      clue_ranges = []
      remainder = range
      range.each do |location|
        next if (board_view[location].nil? || board_view[location] == clue.colour) &&
          board_view.colour_limits_include?(location, clue.colour)

        left = (remainder.first...location)
        clue_ranges << left if left.size >= clue.count
        remainder = (location + 1...remainder.last)
      end
      clue_ranges << remainder if remainder.size >= clue.count
      clue_ranges
    end.map.with_index do |ranges, clue_index|
      # Limit ranges where they abut with solutions of the same colour.
      clue = self[clue_index]
      ranges.map do |range|
        while range.size >= clue.count &&
            (
              (range.first > 0 && board_view[range.first - 1] == clue.colour) ||
              (
                range.first + clue.count < board_view.length - 1 &&
                board_view[range.first + clue.count] == clue.colour
              )
            )
          range = (range.first + 1...range.last)
        end
        while range.size >= clue.count &&
            (
              (range.last < board_view.length - 1 && board_view[range.last] == clue.colour) ||
              (
                range.last - clue.count > 0 &&
                board_view[range.last - clue.count - 1] == clue.colour
              )
            )
          range = (range.first...range.last - 1)
        end
        range if range.size >= clue.count
      end.compact
    end
  end

  def limit_range_overlap(ranges)
    # Limit ranges so that they don't invalidly overlap.
    # Left to right
    (0...ranges.length - 1).each do |ranges_index|
      left_ranges = ranges[ranges_index]
      right_ranges = ranges[ranges_index + 1]
      left_clue = self[ranges_index]
      right_clue = self[ranges_index + 1]
      spacer = left_clue.colour == right_clue.colour ? 1 : 0

      min = left_ranges.first.first + spacer + left_clue.count
      while right_ranges.first.first < min
        range = (min...right_ranges.first.last)
        if range.size < right_clue.count
          right_ranges.shift
        else
          right_ranges[0] = range
        end
      end
    end

    # Right to left
    (ranges.length - 2..0).step(-1).each do |ranges_index|
      left_ranges = ranges[ranges_index]
      right_ranges = ranges[ranges_index + 1]
      left_clue = self[ranges_index]
      right_clue = self[ranges_index + 1]
      spacer = left_clue.colour == right_clue.colour ? 1 : 0

      max = right_ranges.last.last - spacer - right_clue.count
      while left_ranges.last.last > max
        range = (left_ranges.last.first...max)
        if range.size < left_clue.count
          left_ranges.pop
        else
          left_ranges[-1] = range
        end
      end
    end

    ranges
  end

  def remove_invalid_ranges(board_view, all_ranges)
    # Need to be careful with this method as it can have a large runtime complexity
    combo_count = all_ranges.map(&:length).reduce(&:*)
    return all_ranges if combo_count > 1000

    # Enumerate the combinations of ranges and eliminate those where:
    # - it leaves orphaned solutions
    # - it has invalid range overlap

    # Convert the board view to ranges of colour cells.
    board_ranges = []
    last_cell_index = nil
    board_view.each_with_index do |cell, index|
      if cell.nil? || cell == Puzzle::BLANK
        if !last_cell_index.nil?
          board_ranges << (last_cell_index...index)
          last_cell_index = nil
        end
      elsif last_cell_index.nil?
        last_cell_index = index
      end
    end
    board_ranges << (last_cell_index...board_view.length) if last_cell_index

    result = []
    all_ranges[0].product(*all_ranges[1..]) do |combo|
      # Ensure that any overlap is valid. The end of the next range cannot be before the max
      # of the beginnings of all previous ranges.
      min = combo[0].first
      next unless (0...combo.length - 1).all? do |combo_index|
        left = combo[combo_index]
        right = combo[combo_index + 1]
        min = [min, left.first].max
        min < right.last
      end

      # Coalesce combo elements that overlap or abut.
      coalesced_combo = self.class.coalesce_ranges(combo)

      # Ensure the combo doesn't leave any orphans
      next unless board_ranges.all? do |board_range|
        coalesced_combo.any? { _1.cover?(board_range) }
      end

      result << combo
    end

    # Reassemble the combos into an array of arrays
    result.first.zip(*result[1..]).map(&:uniq)
  end

  def limit_ranges_using_matches(ranges, bv, matches)
    bvcs = bv.to_clues
    matches.each do |(bi, ci)|
      board_clue = bvcs[bi]
      clue = self[ci]
      clue_ranges = ranges[ci]

      # Find the clue range that includes the board clue
      range = clue_ranges.find { _1.cover?(board_clue.solution) }

      diff = clue.count - board_clue.count
      from = [board_clue.solution - diff, range.first].max
      to = [board_clue.to + diff, range.last].min

      ranges[ci] = [(from...to)]
    end
    ranges = limit_range_overlap(ranges)
    remove_invalid_ranges(bv, ranges)
  end

  # def limit_colours_using_ranges(bv, ranges)
  #   colour_ranges = ranges.zip(self).group_by { _1[1].colour }.
  #     transform_values { self.class.coalesce_ranges(_1.map(&:first).flatten) }.to_a

  #   (0...bv.length).each do |index|
  #     next unless bv[index].nil?

  #     colours = colour_ranges.select { _1[1].any? { |r| r.cover?(index) } }.map(&:first)
  #     bv.limit_colours(index, colours)
  #   end
  # end

  def match(board_view)
    ranges = ranges(board_view)
    bvcs = board_view.to_clues
    matches = match_from_ranges(ranges, bvcs)
    mark_solved_clues(matches, bvcs)
  end

  def match_from_ranges(ranges, bvcs)
    matches = {}
    bvcs.each_with_index do |board_clue, board_clue_index|
      next if board_clue.colour == Puzzle::BLANK

      board_clue_from = board_clue.solution
      board_clue_to = board_clue.solution + board_clue.count
      matches[board_clue_index] = []

      ranges.each_with_index do |clue_ranges, clue_index|
        clue = self[clue_index]
        next if clue.colour != board_clue.colour
        next if clue.count < board_clue.count

        clue_ranges.each do |range|
          next unless self.class.contains?(range.first, range.last, board_clue_from, board_clue_to)

          # Determine if the board clue is an exclusive match with the range.
          exclusive = clue_ranges.one? &&
            board_clue_from - range.first < 2 && range.last - board_clue_to < 2

          if exclusive
            raise "Range already has an exclusive match" if matches[board_clue_index].is_a?(Integer)

            matches[board_clue_index] = clue_index
          elsif matches[board_clue_index].is_a?(Array)
            matches[board_clue_index] << clue_index
          end
          break
        end
      end
    end

    self.class.resolve_multiple_matches(matches)
  end

  def self.resolve_multiple_matches(matches)
    matches = matches.to_a

    loop do
      change = false

      # Change single elements arrays to ints
      matches.each do |m|
        next unless m[1].is_a?(Array) && m[1].one?

        m[1] = m[1].first
        change = true
      end

      # Remove array elements where their values are less than previous ints
      min = nil
      matches.each do |(_bi, ci)|
        if ci.is_a?(Array)
          next if min.nil?

          ci.filter! do |e|
            next true if e >= min

            change = true
            false
          end
        else
          min = ci
        end
      end

      # Remove array elements where their values are greater than subsequent ints
      max = nil
      matches.reverse_each do |(_bi, ci)|
        if ci.is_a?(Array)
          next if max.nil?

          ci.filter! do |e|
            next true if e <= max

            change = true
            false
          end
        else
          max = ci
        end
      end

      break unless change
    end

    matches.select { |m| m[1].is_a?(Integer) }.to_h
  end

  def mark_solved_clues(matches, bvcs)
    matches.each do |(board_clue_index, clue_index)|
      board_clue = bvcs[board_clue_index]
      clue = self[clue_index]
      next unless board_clue.count == clue.count

      clue.solve(board_clue.solution)
    end
  end

  def match_recursive(bv)
    bvcs = bv.to_clues
    return {} if bvcs.empty?

    # Start with the already known matches
    matches = match_clues_to_board_clues(bvcs)

    loop do
      last_match_count = matches.length

      if matches.empty?
        matches = match(bv)
      else
        matches_arr = matches.to_a

        # Left
        if matches_arr[0][1] > 0
          solution_index, clue_index = matches_arr[0]
          matches = sub_matches(bv, 0, clue_index, bvcs, nil, solution_index, matches)
        end

        # In betweens
        matches_arr.each_cons(2) do |(left_board_i, left_clue_i), (right_board_i, right_clue_i)|
          next if left_clue_i + 1 >= right_clue_i

          matches = sub_matches(
            bv, left_clue_i + 1, right_clue_i, bvcs, left_board_i, right_board_i, matches
          )
        end

        # Right
        if matches_arr[-1][1] < length - 1
          solution_index, clue_index = matches_arr[-1]
          matches = sub_matches(bv, clue_index + 1, length, bvcs, solution_index, nil, matches)
        end
      end

      break if matches.length == last_match_count
    end

    matches
  end

  def sub_matches(bv, clue_from, clue_to, bvcs, board_clue_from, board_clue_to, matches)
    # Check if the board clue beside the boundaries could fit with that solution inside the
    # matching clue. If so, abort.
    if clue_from > 0 && board_clue_from + 1 < bvcs.length
      clue = self[clue_from - 1]
      board_clue = bvcs[board_clue_from]
      next_board_clue = bvcs[board_clue_from + 1]
      if next_board_clue.colour == clue.colour &&
          (next_board_clue.to <= board_clue.solution + clue.count)
        return matches
      end
    end
    if clue_to < length # && board_clue_to > 0
      clue = self[clue_to]
      board_clue = bvcs[board_clue_to]
      previous_board_clue = bvcs[board_clue_to - 1]
      if previous_board_clue.colour == clue.colour &&
          (previous_board_clue.solution >= board_clue.to - clue.count)
        return matches
      end
    end

    # Create a sub-view of the board. We want to remove any padding, but since spaces are
    # solution clues, if we remove padding from the left side we need to increment the solution
    # index.
    board_from = board_clue_from.nil? ? 0 : bvcs[board_clue_from].to
    board_to = board_clue_to.nil? ? bv.length : bvcs[board_clue_to].solution
    sub_bv = bv.view(board_from, board_to)
    padding = sub_bv.padding
    board_clue_from ||= -1
    board_clue_from += 1 if padding[0] > 0
    new_matches = view(board_from + padding[0], clue_from, clue_to).
      match_recursive(sub_bv.view(*padding))

    # Matches are in the indexes of their sub-views. We need to translate them
    # back to the current view.
    new_matches = new_matches.to_h { |s, c| [s + board_clue_from + 1, c + clue_from] }

    # The ordering of the matches is important.
    matches.merge(new_matches).to_a.sort_by(&:first).to_h
  end

  def match_clues_to_board_clues(bvcs)
    matches = {}
    bvcs_index = 0
    each_with_index do |clue, index|
      next unless clue.solved?

      bvcs_index += 1 while bvcs[bvcs_index] && bvcs[bvcs_index].solution < clue.solution
      matches[bvcs_index] = index if bvcs[bvcs_index] && bvcs[bvcs_index].solution == clue.solution
    end
    matches
  end

  def fill(board_view)
    diff = board_view.length - sum
    offset = 0
    last_clue_colour = nil
    each do |clue|
      if clue.colour == last_clue_colour
        board_view[offset] = Puzzle::BLANK if diff == 0
        offset += 1
      end
      (diff...clue.count).each { |i| board_view[offset + i] = clue.colour }
      offset += clue.count
      last_clue_colour = clue.colour
    end
  end

  def to_s
    "[#{map(&:to_s).join(',')}]"
  end

  def match_bfi(board_view)
    solutions = find_all_solutions_bfi(board_view)
    matches = {}
    iterations = 0
    board_view.to_clues.each_with_index do |board_clue, board_clue_index|
      next if board_clue.colour == Puzzle::BLANK

      board_clue_from = board_clue.solution
      board_clue_to = board_clue.solution + board_clue.count
      matches[board_clue_index] = nil

      solutions.each do |solution|
        solution.each_with_index do |location, clue_index|
          iterations += 1
          puts "BFI match aborted" if iterations == 1_000_000
          break if iterations >= 1_000_000

          next if matches[board_clue_index] == clue_index

          clue = self[clue_index]
          clue_from = location
          clue_to = location + clue.count

          if self.class.overlap?(board_clue_from, board_clue_to, clue_from, clue_to)
            if matches[board_clue_index].nil?
              matches[board_clue_index] = clue_index
            elsif matches[board_clue_index] != clue_index
              matches.delete(board_clue_index)
              break
            end
          end
        end

        break unless matches.key?(board_clue_index)
      end
    end

    # puts "Match iterations: #{iterations}"
    matches
  end

  def self.overlap?(from_1, to_1, from_2, to_2)
    (from_2 >= from_1 && from_2 < to_1) ||
      (to_2 > from_1 && to_2 <= to_1) ||
      (from_2 < from_1 && to_2 > to_1)
  end

  def self.contains?(container_from, container_to, containee_from, containee_to)
    container_from <= containee_from && container_to >= containee_to
  end

  def find_all_solutions_bfi(board_view)
    max_first_location = board_view.length - sum

    # freedom = board_view.length - sum + 1
    # clues = length
    # puts "freedom: #{freedom}, clues: #{clues}, complexity: #{freedom**clues}"
    iterations = 0

    solutions = []
    locations = []
    move_last_clue = false
    loop do
      iterations += 1
      puts "BFI find aborted" if iterations == 1_000_000
      break if iterations >= 1_000_000

      if move_last_clue
        # Increment the current location
        locations[-1] += 1
        clue_index = locations.length - 1

        # Short curcuit
        break if clue_index.zero? && locations[-1] > max_first_location

        clue = self[clue_index]
      else
        clue_index = locations.length
        clue = self[clue_index]

        # Find the first valid location for the clue
        previous_clue = clue_index.zero? ? nil : self[clue_index - 1]
        location = previous_clue.nil? ? 0 : locations[-1] + previous_clue.count
        location += 1 if clue.colour == previous_clue&.colour
        locations << location
      end

      location = locations[-1]
      while location + clue.count <= board_view.length
        break if clue.valid_location_bfi?(board_view, location)

        location += 1
      end

      if location + clue.count <= board_view.length
        locations[-1] = location

        if locations.length == length
          # Make sure that the spaces in between the clues don't contain any solved cells.
          valid = (0..length).all? do |i|
            from = i.zero? ? 0 : locations[i - 1] + self[i - 1].count
            to = i == length ? board_view.length : locations[i]
            (from...to).all? { |l| board_view[l].nil? || board_view[l] == Puzzle::BLANK }
          end

          solutions << locations.dup if valid
          move_last_clue = true
        else
          move_last_clue = false
        end
      else
        break if clue_index.zero?

        move_last_clue = true
        locations.pop
      end
    end

    # puts "Find iterations: #{iterations}"

    solutions
  end

  def self.coalesce_ranges(ranges)
    coalesced = []
    sorted = ranges.sort_by(&:first)
    last_range = sorted.first
    sorted[1..].each do |range|
      next if last_range.cover?(range)

      if range.cover?(last_range)
        last_range = range
      elsif range.first <= last_range.last
        last_range = (last_range.first...range.last)
      else
        coalesced << last_range
        last_range = range
      end
    end
    coalesced << last_range
    coalesced
  end
end
