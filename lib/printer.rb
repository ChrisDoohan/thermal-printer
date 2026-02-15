require "nokogiri"
require "escpos"

class Printer
  class NotAvailable < StandardError; end

  DEVICE_PATH = "/dev/usb/lp0"

  def initialize
    @buffer = "".b
    init_printer
  end

  def available?
    File.exist?(DEVICE_PATH) && File.writable?(DEVICE_PATH)
  end

  def send_raw(bytes)
    @buffer << bytes.force_encoding("ASCII-8BIT")
  end

  def send_text(text)
    @buffer << sanitize_unicode(text).encode("CP1252", undef: :replace, replace: "?")
  end

  def send_line(line)
    send_text(line + "\n")
  end

  def bold_on()     @buffer << "\x1B\x45\x01" end
  def bold_off()    @buffer << "\x1B\x45\x00" end
  def uline_on()    @buffer << "\x1B\x2D\x01" end
  def uline_off()   @buffer << "\x1B\x2D\x00" end
  def uline2_on()   @buffer << "\x1B\x2D\x02" end
  def uline2_off()  @buffer << "\x1B\x2D\x00" end
  def invert_on()   @buffer << "\x1D\x42\x01" end
  def invert_off()  @buffer << "\x1D\x42\x00" end

  def align_left()   @buffer << "\x1B\x61\x00" end
  def align_center() @buffer << "\x1B\x61\x01" end
  def align_right()  @buffer << "\x1B\x61\x02" end

  def set_size(n)
    v = ((n - 1) << 4) | (n - 1)
    @buffer << "\x1D\x21" + v.chr
  end

  def reset_size() @buffer << "\x1D\x21\x00" end

  def send_html(html)
    doc = Nokogiri::HTML.fragment(html)
    walk(doc)
  end

  def cut
    @buffer << "\n\n\n\n\n"
    @buffer << "\x1B\x69" # ESC i - partial cut
    flush
  end

  def flush
    raise NotAvailable, "Printer not available at #{DEVICE_PATH}" unless available?
    File.open(DEVICE_PATH, "wb") { |f| f.write(@buffer) }
    @buffer = "".b
  end

  private

  HEADING_SIZES = { "h1" => 4, "h2" => 3, "h3" => 2 }.freeze

  VULGAR_FRACTIONS = {
    "\u00BC" => "1/4",   # ¼
    "\u00BD" => "1/2",   # ½
    "\u00BE" => "3/4",   # ¾
    "\u2150" => "1/7",   # ⅐
    "\u2151" => "1/9",   # ⅑
    "\u2152" => "1/10",  # ⅒
    "\u2153" => "1/3",   # ⅓
    "\u2154" => "2/3",   # ⅔
    "\u2155" => "1/5",   # ⅕
    "\u2156" => "2/5",   # ⅖
    "\u2157" => "3/5",   # ⅗
    "\u2158" => "4/5",   # ⅘
    "\u2159" => "1/6",   # ⅙
    "\u215A" => "5/6",   # ⅚
    "\u215B" => "1/8",   # ⅛
    "\u215C" => "3/8",   # ⅜
    "\u215D" => "5/8",   # ⅝
    "\u215E" => "7/8",   # ⅞
    "\u215F" => "1/",    # ⅟ (fraction numerator one)
    "\u2189" => "0/3",   # ↉
    "\u2044" => "/",     # ⁄ (fraction slash)
  }.freeze

  VULGAR_FRACTIONS_RE = Regexp.union(VULGAR_FRACTIONS.keys)

  def sanitize_unicode(text)
    text.gsub(VULGAR_FRACTIONS_RE, VULGAR_FRACTIONS)
  end

  def walk(node)
    node.children.each do |child|
      case child.type
      when Nokogiri::XML::Node::TEXT_NODE
        send_text(child.text)
      when Nokogiri::XML::Node::ELEMENT_NODE
        has_invert = child["style"].to_s.include?("background-color") || child.name.downcase == "mark"
        invert_on if has_invert

        name = child.name.downcase
        case name
        when "b", "strong"
          bold_on; walk(child); bold_off
        when "u"
          uline2_on; walk(child); uline2_off
        when "i", "em"
          uline_on; walk(child); uline_off
        when "h1", "h2", "h3"
          apply_alignment(child) do
            set_size(HEADING_SIZES[name]); bold_on
            walk(child)
            bold_off; reset_size; send_text("\n")
          end
        when "p"
          apply_alignment(child) do
            walk(child)
            send_text("\n")
          end
        when "br"
          send_text("\n")
        else
          walk(child)
        end

        invert_off if has_invert
      end
    end
  end

  def apply_alignment(node)
    classes = node["class"].to_s
    if classes.include?("ql-align-center")
      align_center
      yield
      align_left
    elsif classes.include?("ql-align-right")
      align_right
      yield
      align_left
    else
      yield
    end
  end

  def init_printer
    @buffer << "\x1B\x40"     # ESC @ - Initialize printer
    @buffer << "\x1C\x2E"     # FS .  - Cancel CJK mode
    @buffer << "\x1B\x74\x06" # ESC t 6 - Set code page to CP1252
  end
end
