require "pry"
require "pry-remote"
require "pry-nav"

require "./clue"
require "./clue_view"

describe ClueView do
  context "#solve" do
    it "works" do
      clue = Clue.new(5, :a)
      view = ClueView.new(clue, 9)
      view.solve(6)
      expect(view.solution).to(eq(6))
      expect(clue.solution).to(eq(15))
    end
  end

  context "#to" do
    it "works" do
      clue = Clue.new(5, :a, 14)
      view = ClueView.new(clue, 9)
      expect(view.to).to(eq(10))
    end
  end

  context "#to_s" do
    it "works" do
      expect(ClueView.new(Clue.new(5, :a), 9).to_s).to(eq("5a"))
      expect(ClueView.new(Clue.new(5, :a, 15), 9).to_s).to(eq("5a(6)"))
    end
  end
end
