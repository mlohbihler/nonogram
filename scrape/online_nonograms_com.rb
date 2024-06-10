require "faraday"
require "nokogiri"
require "pry"
require "pry-remote"
require "pry-nav"

# https://onlinenonograms.com/17465
class OnlineNonogramsCom
  CODES = ("a".."z").to_a.freeze

  def self.fetch_ids
    response = Faraday.get(
      "https://onlinenonograms.com/index.php",
      {
        place: "catalog",
        kat: 0,
        color: "",
        size: "smart",
        star: "",
        filtr: "all",
        sort: "sortstard",
        noset: 2,
        page: 1,
      }
    )
    doc = Nokogiri::HTML(response.body)
    doc.css(".catitem > a").map { _1.attr("href").to_i }
  end

  def self.fetch(id)
    url = "https://onlinenonograms.com/#{id}"
    response = Faraday.get(url)
    doc = Nokogiri::HTML(response.body)

    colours = doc.css("#maincolors .color_button").
      select { _1.attr("abbr") }.
      map.with_index do |button, i|
        {
          abbr: button.attr("abbr"),
          colour: parse_styles(button)["background-color"],
          code: CODES[i],
        }
      end
    colour_code_lookup = colours.to_h { [_1[:colour], _1[:code]] }
    colours << { code: " ", colour: "#ffffff" }

    top_clue_rows = doc.css("#cross_top tr")
    column_count = top_clue_rows.first.children.length
    top_clues = (0...column_count).map { [] }
    top_clue_rows.each do |row|
      row.children.each_with_index do |e, i|
        next if e.content.empty?

        count = e.content.to_i
        colour = parse_styles(e)["background-color"] || colour_code_lookup.keys.first
        code = colour_code_lookup[colour]
        top_clues[i] << "#{count}#{code}" if code
      end
    end
    top_clues = top_clues.map { _1.join(",") }

    left_clue_rows = doc.css("#cross_left tr")
    left_clues = left_clue_rows.map do |row|
      row.children.map do |e|
        next if e.content.empty?

        count = e.content.to_i
        colour = parse_styles(e)["background-color"] || colour_code_lookup.keys.first
        code = colour_code_lookup[colour]
        "#{count}#{code}" if code
      end.compact.join(",")
    end

    File.write(
      "puzzles/online_nonograms_com/#{id}.json",
      JSON.pretty_generate(
        [
          top_clues,
          left_clues,
          colours.to_h { [_1[:code], _1[:colour]] },
        ]
      )
    )
  end

  def self.parse_styles(ele)
    style = ele.attr("style")
    return {} if style.nil?

    style.split(";").reject { _1.strip.empty? }.to_h do |option|
      option.split(":").map(&:strip)
    end
  end

  # puts fetch_ids
  fetch(16624)

  # fetch(19268)
  # fetch(19262)
  # fetch(19267)
  # fetch(19259)
  # fetch(19269)
  # fetch(19266)
  # fetch(19260)
  # fetch(15983)
  # fetch(16061)
  # fetch(17201)
  # fetch(15335)
  # fetch(16877)
  # fetch(17185)
  # fetch(15968)
  # fetch(16896)
  # fetch(15749)
  # fetch(15624)
  # fetch(15698)
  # fetch(16717)
  # fetch(15945)
  # fetch(16789)
  # fetch(17364)
  # fetch(15322)
  # fetch(17193)
  # fetch(15281)
  # fetch(16574)
  # fetch(16619)
  # fetch(17098)
  # fetch(17698)
  # fetch(16757)
  # fetch(17291)
  # fetch(16577)
  # fetch(15399)
  # fetch(16733)
  # fetch(16763)
  # fetch(15756)
  # fetch(15123)
  # fetch(16647)
  # fetch(15998)
  # fetch(15642)
  # fetch(15966)
  # fetch(17596)
  # fetch(15639)
  # fetch(17081)
  # fetch(17350)
  # fetch(17446)
  # fetch(16585)
  # fetch(17289)
end
