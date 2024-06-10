require "./board"
require "./board_view"
require "./clue"
require "./clue_set"

describe BoardView do
  def create_views(clues, board_input, colours: nil)
    bv = Board.from_strings([board_input]).view(0, true)
    if colours
      colour_sets = colours.split(",").map { _1.empty? ? nil : _1.chars.to_set(&:to_sym) }
      raise "board input: #{board_input.length}, colours: #{colour_sets.length}" if board_input.length != colour_sets.length

      (0...bv.length).each do |i|
        colour_set = colour_sets[i]
        bv.limit_colours(i, colour_set.delete(Puzzle::BLANK)) if colour_set
      end
    end
    [bv, ClueSet.new(clues).view]
  end

  context "#to_clues" do
    it "returns nothing when there are no solved cells" do
      board = Board.from_strings([".........."])
      view = described_class.new(board, 0, true, 0, 10)
      expect(view.to_clues).to(eq(ClueSet.new([])))
    end

    it "returns correct clues including start positions" do
      board = Board.from_strings([".aab.bc. ."])
      view = described_class.new(board, 0, true, 0, 10)
      expect(view.to_clues).to(
        eq(
          ClueSet.new(
            [
              Clue.new(2, :a, 1),
              Clue.new(1, :b, 3),
              Clue.new(1, :b, 5),
              Clue.new(1, :c, 6),
              Clue.new(1, :" ", 8),
            ]
          )
        )
      )
    end

    it "returns correct clues when solved cells are at the edges" do
      board = Board.from_strings(["aaa.....bb"])
      view = described_class.new(board, 0, true, 0, 10)
      expect(view.to_clues).to(
        eq(
          ClueSet.new(
            [
              Clue.new(3, :a, 0),
              Clue.new(2, :b, 8),
            ]
          )
        )
      )
    end

    it "returns correct clues when there is an offset" do
      board = Board.from_strings(["  ..aaa..bb  "])
      view = described_class.new(board, 0, true, 2, 11)
      expect(view.to_clues).to(
        eq(
          ClueSet.new(
            [
              Clue.new(3, :a, 2),
              Clue.new(2, :b, 7),
            ]
          )
        )
      )
    end
  end

  context "#trim" do
    it "works" do
      expect(Board.from_strings(["  aaabb   "]).view(0, true).trim.to_s).to(eq("aaabb"))
      expect(Board.from_strings(["aaabb             "]).view(0, true).trim.to_s).to(eq("aaabb"))
      expect(Board.from_strings(["            aaabb"]).view(0, true).trim.to_s).to(eq("aaabb"))
      expect(Board.from_strings(["aaabb"]).view(0, true).trim.to_s).to(eq("aaabb"))
      expect(Board.from_strings(["    "]).view(0, true).trim.to_s).to(eq(""))
      expect(Board.from_strings(["  a  "]).view(0, true).trim.to_s).to(eq("a"))
      expect(Board.from_strings([" a "]).view(0, true).trim.to_s).to(eq("a"))
      expect(Board.from_strings(["a"]).view(0, true).trim.to_s).to(eq("a"))
      expect(Board.from_strings([" "]).view(0, true).trim.to_s).to(eq(""))
      expect(Board.from_strings([""]).view(0, true).trim.to_s).to(eq(""))
    end
  end

  context "#fill_from_ranges" do
    def call(clues, board, colours: nil)
      bv, csv = create_views(clues, board, colours: colours)
      bv.fill_from_ranges(csv)
      bv.to_s
    end

    it "works" do
      expect(call("3b", "......")).to(eq("......"))
      expect(call("4b", " ......")).to(eq(" ..bb.."))
      expect(call("5b", "  ......")).to(eq("  .bbbb."))
      expect(call("6b", "......")).to(eq("bbbbbb"))
      expect(call("3b", ".......")).to(eq("......."))
      expect(call("4b", ".......")).to(eq("...b..."))
      expect(call("5b", "  .......   ")).to(eq("  ..bbb..   "))
      expect(call("6b", ".......")).to(eq(".bbbbb."))
      expect(call("7b", ".......")).to(eq("bbbbbbb"))
      expect(call("2b,2b", "... ....")).to(eq(".b. ...."))
    end
  end

  context "#fill_from_matches" do
    def call(board, clues, bfi: false)
      board_view = Board.from_strings([board]).view(0, true)
      csv = ClueSet.new(clues).view(0, 0)
      board_view.fill_from_matches(csv, bfi: bfi)
      board_view.to_s
    end

    it "works" do
      # expect(call("aa....a......aaa ", "2a,1a,1a,3a")).to(eq("aa .. a .... aaa "))
      expect(call(". a....", "1a,1a")).to(eq(". a ..."))
      expect(call(".......", "")).to(eq("......."))
      # expect(call("......     ...", "4a,2a")).to(eq("..aa..     .a."))
      # expect(call("...b..b...b .b.b... ", "4b,1b,3b")).to(eq("...b..b.  b .bbb..  "))
      expect(call(".....gggbgg.bgggbbg.bbbbb.                   ", "1b,1g,1b,3g(5),1b,3g,1b,3g,2b,2g,6b")).
        to(eq(    ".....gggbgggbgggbbggbbbbbb                   "))
    end

    it "doesn't actually change anything, but would be nice if it did" do
      # nothing to do yet
    end

    xit "works using bfi" do
      expect(call(".....ggg.gg.bggg..g.bb....   ... ............", "1b,1g,1b,3g(5),1b,3g,1b,3g,2b,2g,6b", bfi: true)).
        to(eq(    ".....gggbgggbgggbbggbbbbbb                   "))
      expect(call(".....gggbgg.bgggbbg.bbbbb.                   ", "1b,1g,1b,3g(5),1b,3g,1b,3g,2b,2g,6b", bfi: true)).
        to(eq(    ".....gggbgggbgggbbggbbbbbb                   "))
      expect(call(".....gggbgggbgggbbggbbbbb.                   ", "1b,1g,1b,3g(5),1b,3g,1b,3g,2b,2g,6b", bfi: true)).
        to(eq(    ".....gggbgggbgggbbggbbbbbb                   "))
    end
  end

  context "#fill_in_between_matches" do
    def call(board, clues)
      board_view = Board.from_strings([board]).view(0, true)
      csv = ClueSet.new(clues).view
      board_view.fill_in_between_matches(csv, board_view.to_clues, csv.match(board_view))
      board_view.to_s
    end

    context "when filling before a match" do
      it "works" do
        expect(call("....x..", "2a,1a,1x")).to(eq("aa ax.."))
        expect(call("....x..", "2a,1b,1x")).to(eq(".a..x.."))
        expect(call(" ...x..", "2a,1b,1x")).to(eq(" aabx.."))
        expect(call(".. .x..", "2a,1b,1x")).to(eq(".a .x.."))
        expect(call("... x..", "2a,1b,1x")).to(eq("aab x.."))
      end
    end

    context "when filling between matches" do
      it "works" do
        expect(call("aa..x..", "2a,1a,1x")).to(eq("aa.ax.."))
        expect(call("aa .x..", "2a,1a,1x")).to(eq("aa ax.."))
      end

      it "fills space between board clues for the same clue" do
        expect(call("..aa....aaa.", "11a")).to(eq("..aaaaaaaaa."))
      end

      it "extrapolates from adjacent clues, and fills spaces between them" do
        expect(call(".a.......bb.", "2a,3b")).to(eq(".a.     .bb."))
        expect(call(".aa.....bbb.", "2a,3b")).to(eq(".aa     bbb."))
        expect(call("..aa..aaa..", "4a,5a")).to(eq(".aaa..aaaa."))
      end
    end

    context "when filling after a match" do
      it "works" do
        expect(call("..aaa...", "4a,2a")).to(eq("..aaa.aa"))
        expect(call("..aaa...", "4a,2b")).to(eq("..aaa.b."))
      end
    end
  end

  context "#fill_from_edges" do
    def call(board, clues)
      board_view = Board.from_strings([board]).view(0, true)
      csv = ClueSet.new(clues).view
      board_view.fill_from_edges(csv, board_view.to_clues, csv.match(board_view))
      board_view.to_s
    end

    it "works" do
      # expect(call("    .... b..    bb  ", "2b,3b,2b")).to(eq("    .... bbb    bb  "))
      expect(call("..aaa...........", "10a")).to(eq("..aaaaaaaa..    "))
      expect(call("aaa...........", "10a")).to(eq("aaaaaaaaaa    "))
      expect(call(".....aaa......", "8a")).to(eq(".....aaa..... "))
      expect(call(".....aaa......", "7a")).to(eq(" ....aaa....  "))
      expect(call("...aaa.......", "11a")).to(eq("..aaaaaaaaa.."))
      expect(call("...........aaa..", "10a")).to(eq("    ..aaaaaaaa.."))
      expect(call("...........aaa", "10a")).to(eq("    aaaaaaaaaa"))
      expect(call(".aaa.... .. ....bb", "7a,2c,4b")).to(eq(".aaaaaa. .. ..bbbb"))
      expect(call("  .aa....   .b.  .cc.  .....d   ", "7a,3b,3c,2d")).to(eq("  aaaaaaa   bbb  .cc.  ....dd   "))
      expect(call("          .b..      ", "3b")).to(eq("          .bb.      "))
      expect(call("..b..  ", "4b")).to(eq(".bbb.  "))
      expect(call("  ..b..", "4b")).to(eq("  .bbb."))
      expect(call(".aaa...   ..    bb..", "7a,2c,4b")).to(eq("aaaaaaa   ..    bbbb"))
      expect(call("....abb....", "4a,5b")).to(eq(" aaaabbbbb "))
      expect(call("....a.bb....", "4a,5b")).to(eq(" .aaa.bbbb. "))
    end
  end

  context "#cap_solved_clues" do
    def call(board, clues)
      board_view = Board.from_strings([board]).view(0, true)
      csv = ClueSet.new(clues).view
      board_view.cap_solved_clues(csv, board_view.to_clues, csv.match(board_view))
      board_view.to_s
    end

    it "works" do
      expect(call("..aaa...", "3a")).to(eq("..aaa..."))
      expect(call("..aaa.....", "3a,1a")).to(eq("..aaa ...."))
    end
  end

  context "#fill_around_blanks" do
    def call(board, clues)
      board_view = Board.from_strings([board]).view(0, true)
      csv = ClueSet.new(clues).view
      board_view.fill_around_blanks(csv, board_view.to_clues, csv.match(board_view))
      board_view.to_s
    end

    it "works" do
      expect(call("b ..bbb.", "1b(0),4b")).to(eq("b  .bbb."))
      expect(call("     bbbggggboooooooooooooob ..bbb.", "3b(5),4g(8),1b(12),14o(13),1b(27),4b")).
        to(eq("     bbbggggboooooooooooooob  .bbb."))
      expect(call("..a..   .bbb...", "4a,6b")).to(eq(".aa..   .bbbbb."))
      expect(call("..a... ...bbb...", "2a,5b")).to(eq("..a.    ..bbb..."))
    end

    it "works for negative cases" do
      expect(call(".....b......ggb.ggggb ......g..... b.........", "2b,3b,2g,2b,2g(12),2b,4g(16),1b(20),5b,2g,1b,3b,1b")).
        to(eq(".....b......ggb.ggggb ......g..... b........."))
      expect(call("..a.. ... .aaa...", "4a,1a,6a")).to(eq("..a.. ... .aaa..."))
      expect(call("..a... ...bbb...", "4a,6b")).to(eq("..a... ...bbb..."))
    end
  end

  # Experimental
  # context "#clue_ranges" do
  #   def call(clues, board, colours: nil)
  #     bv, csv = create_views(clues, board, colours: colours)
  #     bv.clue_ranges(csv)
  #   end

  #   it "works" do
  #     expect(call("1b,1g,1b,3g(5),1b,3g,1b,3g,2b,2g,6b", ".....ggg.gg.bggg..g.bb....   ... ............")).
  #       to(eq([]))
  #   end
  # end
end
