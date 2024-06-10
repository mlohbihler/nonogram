require "./puzzle"
require "pry"
require "pry-remote"
require "pry-nav"
require "set"

class ClueSet
  include Enumerable

  def initialize(clues)
    if clues.is_a?(String)
      clues = clues.split(",").map { |c| Clue.new(c) }
    end
    @clues = clues
  end

  def length
    @clues.length
  end

  def empty?
    @clues.empty?
  end

  def [](index)
    @clues[index]
  end

  def each(&blk)
    @clues.each(&blk)
  end

  def ==(other)
    @clues == other.instance_variable_get(:@clues)
  end

  def to_s
    "[#{@clues.join(',')}]"
  end

  def view(board_offset = 0, from = 0, to = length)
    ClueSetView.new(self, board_offset, from: from, to: to)
  end

  def solved?
    all?(&:solved?)
  end

  def colours
    Set.new(map(&:colour).uniq)
  end
end
