require "./board"
require "./board_view"
require "./clue"
require "./clue_set"
require "./clue_set_view"

describe ClueSetView do
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

  context "#limit_ranges_using_matches" do
    def call(clues, board, colours: nil)
      bv, csv = create_views(clues, board, colours: colours)
      csv.limit_ranges_using_matches(csv.ranges(bv), bv, csv.match_recursive(bv))
    end

    it "works" do
      expect(
        call(
          "1s,5b,1b,1b,1s,1b",
          "      .      ..bbb......b... ......",
          colours: ",,,,,,s,,,,,,,b,b,,,,b,bs,bs,b,bs,b,,b,b,s,,s,s,b,b,s,b"
          #      .      ..bbb......b... ......
          #      s      bb   bbbbbb bbs ssbbsb
          #                   ss s
        )
      ).to(
        eq(
          [[6...7], [13...20], [19...27], [21...27, 31...33], [22...23, 27...28, 29...31, 33...34], [23...27, 31...33, 34...35]]
        )
      )
    end
  end

  context "#remove_invalid_ranges" do
    def call(board, ranges)
      bv, csv = create_views("", board)
      csv.remove_invalid_ranges(bv, ranges)
    end

    it "works" do
      expect(
        call(
          "............b.......a...b..bb..b.............",
          [[0...20, 21...38], [1...12, 13...24, 25...27, 29...31, 32...39], [2...20, 21...40], [4...20, 21...43], [7...20, 21...45]]
        )
      ).to(eq([[0...20], [13...24], [2...20, 21...40], [4...20, 21...43], [21...45]]))
      expect(call("...b..b...b .b.b... ", [[0...9], [6...11, 13...14], [8...11, 13...18]])).
        to(eq([[0...9], [6...11], [13...18]]))
    end
  end

  context "#create_ranges" do
    def call(clues, board, colours: nil)
      bv, csv = create_views(clues, board, colours: colours)
      csv.create_ranges(bv)
    end

    it "works" do
      # But, does it? Really?
    end
  end

  context "#ranges" do
    def call(clues, board, colours: nil)
      bv, csv = create_views(clues, board, colours: colours)
      csv.ranges(bv)
    end

    it "works" do
      expect(call("1b,5g,4g,2g,1s", "..............gg..gg....gg....")).to(
        eq([[0...12], [1...17], [7...26], [14...29], [16...18, 20...24, 26...30]])
      )
      expect(call("1b,1a,1b,2b,1b", "............b.......a...b..bb..b.............")).to(
        eq([[0...20], [13...24], [14...20, 21...40], [16...20, 21...43], [21...45]])
      )

      expect(call("1g,6g,3g,4g,1s,1b,1s,1s", ".....g..........gg. .gggs..........")).to(
        eq(
          [
            [0...12],
            [2...19],
            [9...19, 21...24],
            [20...24, 25...30],
            [24...31],
            [25...32],
            [26...33],
            [28...35],
          ]
        )
      )
      expect(call("3b,2b", "...b......b...")).to(eq([[1...11], [5...14]]))
      expect(call("1b(0),4b", "b ..bbb.")).to(eq([[0...1], [3...8]]))
      expect(call("3b(5),4g(8),1b(12),14o(13),1b(27),4b", "     bbbggggboooooooooooooob ..bbb.")).
        to(eq([[5...8], [8...12], [12...13], [13...27], [27...28], [30...35]]))
      expect(call("2b,3b,2b", "    .... b..    bb  ")).to(eq([[4...8], [9...12], [16...18]]))
      expect(call("2a,2a,2a", "..a...a...")).to(eq([[(1...4)], [(5...7)], [(8...10)]]))
      expect(call("2a,2a,2a", "..a ..a...")).to(eq([[(1...3)], [(5...7)], [(8...10)]]))
      expect(call("3a,2a,5b,1b,3a", "....aa....bbb.b....")).to(
        eq(
          [
            [(0...5)],
            [(4...8)],
            [(8...13)],
            [(14...15)],
            [(15...19)],
          ]
        )
      )
      expect(call("3a,2a,5b,1b,3a", "...aa...b.b.b.....aa.")).to(
        eq(
          [
            [(2...5)],
            [(6...8)],
            [(8...15)],
            [(14...18)],
            [(15...21)],
          ]
        )
      )
      expect(call("7a,2b,6a", "a.a.a.a....b...aa...a")).to(eq([[(0...11)], [(7...15)], [(12...21)]]))
      expect(call("1a,1a", " .a......")).to(eq([[(2...7)], [(4...9)]]))
      expect(call("4a,2a,2a,2a", "....a...a........a")).to(eq([[1...7], [7...12], [10...15], [13...18]]))
      expect(call("4a,2a,2a,2a", ".aaaa...a........a")).to(eq([[1...5], [7...12], [10...15], [13...18]]))
      expect(call("2b,2r,1b,4a", "..........rb..aa....")).to(eq([[0...9], [2...11], [11...14], [12...18]]))
      expect(call("1b,7r,5b,1b", ".....rrrrrr..b..b...")).to(eq([[0...5], [4...12], [12...18], [18...20]]))
      expect(call("3a,3b", ".....   ...")).to(eq([[0...5], [8...11]]))
      expect(call("3a,2a", ".....   ...")).to(eq([[0...5], [8...11]]))
      expect(call("3a,2a", ".....   ......")).to(eq([[0...5, 8...11], [8...14]]))
    end

    it "uses solved colour information to improve range accuracy" do
      # expect(ranges("1b,3g,1b,3g,2b,2g,6b", ".gg.bggg..g.bb....   ... ............")).to(eq([
      #   [0...1, 4...5, 8...10, 15...18],
      #   [1...4, 5...12, 14...18],
      #   [4...5, 8...10, 15...18, 21...24],
      #   [5...12, 14...18, 21...24],
      #   [8...10, 12...18, 21...24, 25...29],
      #   [10...12, 14...18, 21...24, 25...31],
      #   [12...18, 25...37],
      # ]))

      # Too many combinations
      # expect(ranges("1b,1g,1b,3g(5),1b,3g,1b,3g,2b,2g,6b", ".....ggg.gg.bggg..g.bb....   ... ............")).to(eq([
      #   [0...3],
      #   [1...4],
      #   [2...5],
      #   [5...8],
      #   [8...9],
      #   [9...12],
      #   [12...13],
      #   [13...20],
      #   [16...18, 20...26],
      #   [18...20, 22...26, 29...32, 33...39],
      #   [20...26, 33...45],
      # ]))
    end
  end

  context "#limit_range_overlap" do
    def call(clues, ranges)
      csv = ClueSet.new(clues).view
      csv.limit_range_overlap(ranges)
      ranges
    end

    it "works" do
      expect(call("2b,3b", [[4...8, 9...11], [9...12]])).to(eq([[4...8], [9...12]]))
      expect(call("2a,2a", [[5...7], [6...10]])).to(eq([[5...7], [8...10]]))
      expect(
        call(
          "1b,1g,1b,3g(5),1b,3g,1b,3g,2b,2g,6b",
          [
            [0...5, 8...9, 12...13, 16...18],
            [1...4, 18...19, 22...23],
            [2...5, 8...9, 12...13, 16...18, 23...24],
            [5...12, 13...20, 22...26],
            [8...9, 12...13, 16...18, 23...26],
            [9...12, 13...20, 22...26],
            [12...13, 16...18, 23...26, 29...32],
            [13...20, 22...26, 29...32],
            [16...18, 20...26, 29...32, 33...37],
            [17...20, 22...26, 29...32, 33...39],
            [19...26, 33...45],
          ]
        )
      ).to(eq(
        [
          [0...3],
          [1...4],
          [2...5, 8...9, 12...13],
          [5...12, 13...17],
          [8...9, 12...13, 16...18],
          [9...12, 13...20, 22...25],
          [12...13, 16...18, 23...26],
          [13...20, 22...26, 29...32],
          [16...18, 20...26, 29...32, 33...37],
          [18...20, 22...26, 29...32, 33...39],
          [20...26, 33...45],
        ]
      ))
    end
  end

  context "#match_from_ranges" do
    # def match_from_ranges(ranges, bvcs)
    def call(clues, board_input, ranges)
      bv = Board.from_strings([board_input]).view(0, true)
      csv = ClueSet.new(clues).view
      csv.match_from_ranges(ranges, bv.to_clues)
    end

    it "works" do
      expect(
        call(
          "1b,5g,4g,2g,1s",
          "..............gg..gg....gg....",
          [[0...12], [1...17], [7...26], [14...29], [16...18, 20...24, 26...30]]
        )
      ).to(eq({}))
    end
  end

  context "#match" do
    def call(clues, board_input, expected = nil)
      bv = Board.from_strings([board_input]).view(0, true)
      csv = ClueSet.new(clues).view
      expect(csv.match(bv)).to eq(expected || csv.match_bfi(bv))
    end

    it "works with offsets" do
      bv = Board.from_strings([" ..rrrbb"]).view(0, true).trim
      csv = ClueSet.new("1b,3r,2b").view(1)
      expect(csv.match(bv)).to eq({ 0 => 1, 1 => 2 })
    end

    it "works" do
      call("1g,6g,3g,4g,1s,1b,1s,1s", ".....g..........gg. .gggs..........")

      call("1s,1b,12g,2g,3g,1s,1b,1s,1b", ".....ggggggggg.gg. ...g............")
      call("2a,2b,2a", "...a...bb...a...")
      call("2a,2b", "....a..b.......")
      call("4g,2g,4g", "..............gg  g.....g.....")
      call("1b(0),4b", "b ..bbb.")
      call("3b(5),4g(8),1b(12),14o(13),1b(27),4b", "     bbbggggboooooooooooooob ..bbb.")
      call("3a,2a,5b,1b,3a", "..................")
      call("2a,2a,2a", "..a...a...")
      call("3a,2a,5b,1b,3a", "....aa....bbb.b....")
      call("3a,2a,5b,1b,3a", "...aa...b.b.b.....aa.")
      call("7a,2b,6a", "aaaaaaa........")
      call("7a,2b,6a", "a.a.a.a....b...aa...a")
      call("10a,2a", ".a.a...a............")
      call("2b,2r,1b,4a", "..........rb..aa....")
      call("1b,7r,5b,1b", ".....rrrrrr..b..b...")
      call("3b", "          .b..      ")
      call("4b,1b,3b", "...b..b...b .b.b... ", { 0 => 0, 2 => 1, 4 => 2, 5 => 2 })
      call("1b,1g,1b,3g(5),1b,3g,1b,3g,2b,2g,6b", ".....ggg.gg.bggg..g.bb....   ... ............", { 0 => 3, 1 => 5, 2 => 6, 3 => 7 })
    end

    it "matches clues at boundaries" do
      call("1a,1a", "a.........")
      call("1a,1a", ".a.........")
      call("1a,1a", "..a.......")
      call("1a,1a", "......a..")
      call("1a,1a", "........a.")
      call("1a,1a", ".........a")
      call("4a,2a,2a,2a", "....a............a")
      call("4a,2a,2a,2a", "a..............a..")
      call("4a,2a,2a,2a", "....a...a........a")
      call("4a,2a,2a,2a", ".aaaa...a........a")
    end

    it "matches correctly when there are spaces" do
      call("2b,3b,2b", "    .... b..    bb  ")
      call("1a,1a", " .a......")
      call("1a,1a", " ......a. ")
    end
  end

  context "#match_recursive" do
    def call(clues, board_input, expected_clues, colours: nil, expected: nil)
      bv = Board.from_strings([board_input]).view(0, true)
      csv = ClueSet.new(clues).view
      if colours
        colour_sets = colours.split(",").map { _1.empty? ? nil : _1.chars.to_set(&:to_sym) }
        (0...bv.length).each do |i|
          colour_set = colour_sets[i]
          bv.limit_colours(i, colour_set.delete(Puzzle::BLANK)) if colour_set
        end
      end
      expect(csv.match_recursive(bv)).to eq(expected || csv.match_bfi(bv))
      expect(csv.to_s[1..-2]).to eq(expected_clues)
    end

    it "works" do
      call(
        "1b,1s,1b,1s",
        " ..........",
        "1b,1s,1b,1s",
        colours: ",b,b,b,s,b,b,s,s,s,b"
      )

      call("1b,5g,4g,2g,1s", "..............gg..gg....gg....", "", expected: {0=>1, 1=>2, 2=>3})

      call("1b,3r,2b,3r(8),8b", " ..rrrbbrrr.bbbbbbb.", "1b,3r(3),2b(6),3r(8),8b")
      call("1b,4r,3b,2b,1b", "........r...........", "1b,4r,3b,2b,1b")
      call("2b,3b,2b", "....................", "2b,3b,2b")
      call("12g,2g,3g", "...ggggggggg.gg....g........", "12g,2g,3g")
      call("12g,2a,3g", "...ggggggggg.aa....g........", "12g,2a(13),3g")
      call("12g,2g,3g", "...ggggggggg..gg....g........", "12g,2g(14),3g")
      call("12g,2g,3g", ".......ggggg.g.g.gg....g........", "12g,2g,3g")
      call("3g,2g,12g", "........g....gg.ggggggggg...", "3g,2g,12g")
      call("3g,2g,12g", "........g....gg..ggggggggg...", "3g,2g(13),12g")
      call(
        "1d,1c,1d,1b,1d,1c,1d,1a,1d,1c,1d,1b,1d,1c,1d",
        "...d...c...d..b..d...c.d...a..d..c...d...b..d..c..d..",
        "1d(3),1c(7),1d(11),1b(14),1d(17),1c(21),1d(23),1a(27),1d(30),1c(33),1d(37),1b(41),1d(44),1c(47),1d(50)",
        expected: { 0 => 0, 1 => 1, 2 => 2, 3 => 3, 4 => 4, 5 => 5, 6 => 6, 7 => 7, 8 => 8, 9 => 9, 10 => 10, 11 => 11, 12 => 12, 13 => 13, 14 => 14 }
      )

      call("1b,1g,1b,3g(5),1b,3g,1b,3g,2b,2g,6b", ".....gggbgg.bgggbbg.bbbbb.                   ", "1b,1g,1b,3g(5),1b(8),3g,1b(12),3g(13),2b(16),2g,6b")
      call("2a,2b", "....a..b.......", "2a,2b")
      call("1b,2b", "....b..bb.......", "1b(4),2b(7)")
      call("1b,1a,1b,2b,1b", "............b.......a...b..bb..b.............", "1b(12),1a(20),1b(24),2b(27),1b(31)")

      call("1b(0),4b", "b ..bbb.", "1b(0),4b")
      call("3b(5),4g(8),1b(12),14o(13),1b(27),4b", "     bbbggggboooooooooooooob ..bbb.", "3b(5),4g(8),1b(12),14o(13),1b(27),4b")
      call("1b,2b", "....b..bb.......", "1b(4),2b(7)")
      call("2b,4b,2b", "............b.................bbb...................b...........", "2b,4b,2b")

      # TODO: figure out how to make these work.
      call("4g,2g,4g", "..............gg  g.....g.....", "")
      # call("2b,2b,2b", "...b...bb...b...")
      #                 000000000
      #                    1111111111
      #                        222222222
      # => [[0...9], [3...13], [7...16]]
    end
  end

  context "#fill" do
    def create_board_view(input)
      Board.from_strings([input]).view(0, true)
    end

    it "works" do
      clue_set_view = ClueSetView.new(ClueSet.new("1b,7r,8b"))
      board_view = create_board_view("....................")
      clue_set_view.fill(board_view)
      expect(board_view.to_s).to eq(".....rrr....bbbb....")

      clue_set_view = ClueSetView.new(ClueSet.new("1a,1a,1a,1a,1a,"))
      board_view = create_board_view(".........")
      clue_set_view.fill(board_view)
      expect(board_view.to_s).to eq("a a a a a")
    end
  end

  context "#match_bfi" do
    def matches(clues, board)
      csv = ClueSet.new(clues).view
      bv = Board.from_strings([board]).view(0, true)
      csv.match_bfi(bv)
    end

    it "works" do
      expect(matches("1a,1a,4b,2a", " ... ...b... ")).to(eq({ 2 => 2 }))
      expect(matches("1a,1a,4b,2a", " .a. ...b... ")).to(eq({ 1 => 0, 3 => 2 }))
      expect(matches("1a,1a,4b,2a", "..a. ...b... ")).to(eq({ 2 => 2 }))
      expect(matches("4a,4b,2a", "..a.a.b.b... ")).to(eq({ 0 => 0, 1 => 0, 2 => 1, 3 => 1 }))
      expect(matches("1a,1a,4b,2a", "..a.a..b.b..")).to(eq({ 0 => 0, 1 => 1, 2 => 2, 3 => 2 }))
    end
  end

  context ".overlap?" do
    it "works" do
      expect(described_class.overlap?(2, 7, 1, 2)).to(eq(false))
      expect(described_class.overlap?(2, 7, 1, 3)).to(eq(true))
      expect(described_class.overlap?(2, 7, 2, 3)).to(eq(true))
      expect(described_class.overlap?(2, 7, 3, 5)).to(eq(true))
      expect(described_class.overlap?(2, 7, 3, 7)).to(eq(true))
      expect(described_class.overlap?(2, 7, 3, 8)).to(eq(true))
      expect(described_class.overlap?(2, 7, 6, 8)).to(eq(true))
      expect(described_class.overlap?(2, 7, 7, 8)).to(eq(false))
      expect(described_class.overlap?(2, 7, 8, 9)).to(eq(false))

      expect(described_class.overlap?(1, 2, 2, 7)).to(eq(false))
      expect(described_class.overlap?(1, 3, 2, 7)).to(eq(true))
      expect(described_class.overlap?(2, 3, 2, 7)).to(eq(true))
      expect(described_class.overlap?(3, 5, 2, 7)).to(eq(true))
      expect(described_class.overlap?(3, 7, 2, 7)).to(eq(true))
      expect(described_class.overlap?(3, 8, 2, 7)).to(eq(true))
      expect(described_class.overlap?(6, 8, 2, 7)).to(eq(true))
      expect(described_class.overlap?(7, 8, 2, 7)).to(eq(false))
      expect(described_class.overlap?(8, 9, 2, 7)).to(eq(false))
    end
  end

  context ".contains?" do
    it "works" do
      expect(described_class.contains?(2, 7, 1, 2)).to(eq(false))
      expect(described_class.contains?(2, 7, 1, 3)).to(eq(false))
      expect(described_class.contains?(2, 7, 2, 3)).to(eq(true))
      expect(described_class.contains?(2, 7, 3, 5)).to(eq(true))
      expect(described_class.contains?(2, 7, 3, 7)).to(eq(true))
      expect(described_class.contains?(2, 7, 3, 8)).to(eq(false))
      expect(described_class.contains?(2, 7, 6, 8)).to(eq(false))
      expect(described_class.contains?(2, 7, 7, 8)).to(eq(false))
      expect(described_class.contains?(2, 7, 8, 9)).to(eq(false))
    end
  end

  context "#find_all_solutions_bfi" do
    def solutions(clues, board)
      csv = ClueSet.new(clues).view
      bv = Board.from_strings([board]).view(0, true)
      csv.find_all_solutions_bfi(bv)
    end

    it "works for positive cases" do
      expect(solutions("4a,1a,3a", "..a..a...a....a.a..")).to(eq([[2, 9, 14]]))
      expect(solutions("1a", "..")).to(eq([[0], [1]]))
      expect(solutions("1a,2a", ".....")).to(eq([[0, 2], [0, 3], [1, 3]]))
      expect(solutions("1a,2b", "....")).to(eq([[0, 1], [0, 2], [1, 2]]))
      expect(solutions("1a,1a,4b,2a", "a abbbbaa")).to(eq([[0, 2, 3, 7]]))
      expect(solutions("1a,1a,4b,2a", ".........")).to(eq([[0, 2, 3, 7]]))
      expect(solutions("1a,1a,4b,2a", "..........")).to(eq([[0, 2, 3, 7], [0, 2, 3, 8], [0, 2, 4, 8], [0, 3, 4, 8], [1, 3, 4, 8]]))
      expect(solutions("1a,1a,4b,2a", "........b....")).to(
        eq(
          [
            [0, 2, 5, 9],
            [0, 2, 5, 10],
            [0, 2, 5, 11],
            [0, 2, 6, 10],
            [0, 2, 6, 11],
            [0, 2, 7, 11],
            [0, 3, 5, 9],
            [0, 3, 5, 10],
            [0, 3, 5, 11],
            [0, 3, 6, 10],
            [0, 3, 6, 11],
            [0, 3, 7, 11],
            [0, 4, 5, 9],
            [0, 4, 5, 10],
            [0, 4, 5, 11],
            [0, 4, 6, 10],
            [0, 4, 6, 11],
            [0, 4, 7, 11],
            [0, 5, 6, 10],
            [0, 5, 6, 11],
            [0, 5, 7, 11],
            [0, 6, 7, 11],
            [1, 3, 5, 9],
            [1, 3, 5, 10],
            [1, 3, 5, 11],
            [1, 3, 6, 10],
            [1, 3, 6, 11],
            [1, 3, 7, 11],
            [1, 4, 5, 9],
            [1, 4, 5, 10],
            [1, 4, 5, 11],
            [1, 4, 6, 10],
            [1, 4, 6, 11],
            [1, 4, 7, 11],
            [1, 5, 6, 10],
            [1, 5, 6, 11],
            [1, 5, 7, 11],
            [1, 6, 7, 11],
            [2, 4, 5, 9],
            [2, 4, 5, 10],
            [2, 4, 5, 11],
            [2, 4, 6, 10],
            [2, 4, 6, 11],
            [2, 4, 7, 11],
            [2, 5, 6, 10],
            [2, 5, 6, 11],
            [2, 5, 7, 11],
            [2, 6, 7, 11],
            [3, 5, 6, 10],
            [3, 5, 6, 11],
            [3, 5, 7, 11],
            [3, 6, 7, 11],
            [4, 6, 7, 11],
          ]
        )
      )
      expect(solutions("1a,1a,4b,2a", " ... ...b... ")).to(
        eq(
          [[1, 3, 5, 9], [1, 3, 5, 10], [1, 3, 6, 10], [1, 5, 6, 10], [2, 5, 6, 10], [3, 5, 6, 10]]
        )
      )
      expect(solutions("1a,1a,4b,2a", "....bbbbaa")).to(eq([[0, 2, 4, 8], [0, 3, 4, 8], [1, 3, 4, 8]]))
      expect(solutions("3a,2a,5b,1b,3a", "....aa....bbb.b....")).to(eq([[0, 4, 8, 14, 15], [0, 4, 8, 14, 16]]))
      expect(solutions("3a,2a,5b,1b,2a", "....aa....bbb.b....")).to(
        eq(
          [
            [0, 4, 8, 14, 15],
            [0, 4, 8, 14, 16],
            [0, 4, 8, 14, 17],
            [0, 4, 10, 16, 17],
            [3, 7, 10, 16, 17],
            [3, 8, 10, 16, 17],
            [4, 8, 10, 16, 17],
          ]
        )
      )
      expect(solutions("2a,2a,2a", "..a...a...")).to(eq([[1, 5, 8], [2, 5, 8]]))
    end

    it "works for negative cases" do
      expect(solutions("1a,1a,4b,2a", "....")).to(eq([]))
      expect(solutions("1a,1a,4b,2a", "..... ...")).to(eq([]))
    end
  end

  context "#[]" do
    it "works" do
      expect(ClueSet.new("1a,2b,1b,3b").view(3, 2, 3)[0].to_s).to(eq("1b"))
    end
  end

  context "#spacer" do
    it "works" do
      expect(ClueSet.new("1a,2b,1b,2b").view(0, 0).spacer(0, before: true)).to(eq(0))
      expect(ClueSet.new("1a,2b,1b,2b").view(0, 0).spacer(1, before: true)).to(eq(0))
      expect(ClueSet.new("1a,2b,1b,2b").view(0, 0).spacer(2, before: true)).to(eq(1))
      expect(ClueSet.new("1a,2b,1b,2b").view(0, 0).spacer(3, before: true)).to(eq(1))

      expect(ClueSet.new("1a,2b,1b,2b").view(0, 0).spacer(0, before: false)).to(eq(0))
      expect(ClueSet.new("1a,2b,1b,2b").view(0, 0).spacer(1, before: false)).to(eq(1))
      expect(ClueSet.new("1a,2b,1b,2b").view(0, 0).spacer(2, before: false)).to(eq(1))
      expect(ClueSet.new("1a,2b,1b,2b").view(0, 0).spacer(3, before: false)).to(eq(0))
    end
  end

  context ".resolve_multiple_matches" do
    it "works" do
      expect(described_class.resolve_multiple_matches({})).to(eq({}))
      expect(described_class.resolve_multiple_matches({ 0 => [1], 1 => [0, 2], 2 => [3] })).
        to(eq({ 0 => 1, 1 => 2, 2 => 3 }))
      expect(described_class.resolve_multiple_matches({ 0 => 1, 1 => [2], 2 => [2, 3] })).
        to(eq({ 0 => 1, 1 => 2 }))
    end
  end

  context ".coalesce_ranges" do
    it "works" do
      expect(described_class.coalesce_ranges([0...12])).to(eq([0...12]))
      expect(described_class.coalesce_ranges([1...17, 7...26, 14...29])).to(eq([1...29]))
      expect(described_class.coalesce_ranges([16...18, 20...24, 26...30])).to(eq([16...18, 20...24, 26...30]))

      expect(described_class.coalesce_ranges([13...14, 0...12])).to(eq([0...12, 13...14]))
      expect(described_class.coalesce_ranges([12...14, 0...12])).to(eq([0...14]))
    end
  end
end
