require "pry"
require "pry-remote"
require "pry-nav"

class ClueView
  extend Forwardable

  def_delegators :@clue, :solved?, :colour, :count

  def initialize(clue, offset)
    @clue = clue
    @offset = offset
  end

  def solve(index)
    @clue.solve(index + @offset)
  end

  def solution
    @clue.solution.nil? ? nil : @clue.solution - @offset
  end

  def to
    solution + count
  end

  def to_s
    "#{count}#{colour}#{solution ? "(#{solution})" : ''}"
  end
end
