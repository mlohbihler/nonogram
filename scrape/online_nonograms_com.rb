require "base64"
require "faraday"
require "json"
require "zlib"

# Downloads puzzles from https://onlinenonograms.com into the local puzzle format.
#
# Usage: ruby scrape/online_nonograms_com.rb <id> [<id> ...]
#
# Puzzle pages (/en/id/<id>) embed the puzzle as a field "p" in the Next.js flight payload. The
# picross engine (engines/picross/assets/index-*.js, function `rs`) decodes it by swapping the
# characters 2->1, a->2, 1->a, then base64-decoding and inflating raw DEFLATE. The result is JSON
# with "colors" ({"<code>" => "#rrggbb"}), "move", the solution indexed as move[x][y] with EMPTY
# for blank cells, and "en_title"/"ru_title".
#
# Files are saved as [top clues, left clues, colours, solution rows, title].
class OnlineNonogramsCom
  BASE_URL = "https://onlinenonograms.com".freeze
  EMPTY = 9
  CODES = ("a".."z").to_a.freeze

  def self.fetch(id)
    html = Faraday.get("#{BASE_URL}/en/id/#{id}").body
    data = decode(puzzle_field(flight_payload(html), id))

    move = data["move"]
    colour_codes = data["colors"].keys.sort_by(&:to_i).each_with_index.to_h { |k, i| [k.to_i, CODES[i]] }
    rows = (0...move.first.length).map do |y|
      move.map { |column| column[y] == EMPTY ? " " : colour_codes.fetch(column[y]) }.join
    end
    cols = (0...move.length).map { |x| rows.map { _1[x] }.join }

    colours = data["colors"].to_h { |k, hex| [colour_codes.fetch(k.to_i), hex] }
    colours[" "] = "#ffffff"

    path = "puzzles/online_nonograms_com/#{id}.json"
    title = [data["en_title"], data["ru_title"]].find { !_1.to_s.empty? }
    File.write(path, JSON.pretty_generate([cols.map { clues(_1) }, rows.map { clues(_1) }, colours, rows, title]))
    puts "#{path}: #{move.length}x#{rows.length}, #{colours.length - 1} colour(s), #{title}"
  end

  def self.flight_payload(html)
    html.scan(/self\.__next_f\.push\(\[1,(".*?")\]\)<\/script>/m).map { JSON.parse(_1.first) }.join
  end

  # The puzzle's "p" is either inline or a "$<ref>" to a text row "<ref>:T<hex byte length>,<data>".
  def self.puzzle_field(payload, id)
    p = payload[/"id":#{id},"sx":\d+,"sy":\d+,"p":"([^"]*)"/, 1]
    raise "Puzzle #{id} not found in page" if p.nil?
    return p unless p.start_with?("$")

    ref = p.delete_prefix("$")
    match = payload.match(/^#{ref}:T(\h+),/)
    raise "Puzzle data row #{ref} not found" if match.nil?

    payload.byteslice(match.byteoffset(0).last, match[1].to_i(16))
  end

  def self.decode(p)
    raw = Base64.decode64(p.tr("21a", "1a2"))
    JSON.parse(Zlib::Inflate.new(-Zlib::MAX_WBITS).inflate(raw))
  end

  def self.clues(line)
    line.chars.chunk_while { _1 == _2 }.reject { _1.first == " " }.map { "#{_1.length}#{_1.first}" }.join(",")
  end
end

if __FILE__ == $PROGRAM_NAME
  ARGV.each_with_index do |id, i|
    sleep 1 if i > 0 # The site's robots.txt asks for a 1 second crawl delay.
    OnlineNonogramsCom.fetch(id)
  end
end
