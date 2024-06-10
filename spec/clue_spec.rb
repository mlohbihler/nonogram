require "./board"
require "./board_view"
require "./clue"
# require "./clue_set"
# require "./clue_set_view"
require "pry"
require "pry-remote"
require "pry-nav"

describe Clue do
  context ".valid_location_bfi?" do
    it "works" do
      c = described_class.new("2a")
      bv = Board.from_strings(["...a... .b."]).view(0, true)
      expect((0...bv.length - 1).map { |i| c.valid_location_bfi?(bv, i) }).
        to(eq([true, false, true, true, false, true, false, false, false, false]))
    end
  end
end
