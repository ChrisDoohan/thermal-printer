require "bundler/setup"
require "escpos"
require 'debug'

class Printer
  DEVICE_PATH = "/dev/usb/lp0"

  def initialize
    @buffer = "".b
    @initialized = false
  end

  def available?
    File.exist?(DEVICE_PATH) && File.writable?(DEVICE_PATH)
  end

  def send_text(text)
    init_printer unless @initialized
    @buffer << text.encode("CP1252", undef: :replace, replace: "?")
  end

  def send_line(line)
    send_text(line + "\n")
  end

  def cut
    @buffer << "\n\n\n\n\n"
    @buffer << Escpos::Helpers.partial_cut
    flush
  end

  def flush
    File.open(DEVICE_PATH, "wb") { |f| f.write(@buffer) }
    @buffer = "".b
  end

  private

  def init_printer
    @buffer << "\x1B\x40"     # ESC @ - Initialize printer
    @buffer << "\x1C\x2E"     # Cancel CJK mode (FS .)
    @buffer << "\x1B\x74\x06" # Set code page to CP1252 (ESC t 6)
    @initialized = true
  end
end

printer = Printer.new

puts "Printer available? #{printer.available?}"

unless printer.available?
  puts "Printer not found at #{Printer::DEVICE_PATH}"
  exit 1
end

# # Font A (default) vs Font B
# printer.send_line("-- Font A (default) --")
# printer.send_line("The quick brown fox jumps over the lazy dog")
# printer.send_text("\x1B\x4D\x01") # ESC M 1 - Select Font B
# printer.send_line("-- Font B --")
# printer.send_line("The quick brown fox jumps over the lazy dog")
# printer.send_text("\x1B\x4D\x00") # ESC M 0 - Back to Font A
#
# # Bold
# printer.send_text(Escpos::Helpers.bold("This text is bold"))
# printer.send_line("")
#
# # Underline
# printer.send_text(Escpos::Helpers.underline("Single underline"))
# printer.send_line("")
# printer.send_text(Escpos::Helpers.underline2("Double underline"))
# printer.send_line("")
#
# # Inverted
# printer.send_text(Escpos::Helpers.inverted("Inverted text"))
# printer.send_line("")
#
# # Alignment (raw commands — helpers reset alignment before the newline)
# printer.send_text("\x1B\x61\x00") # ESC a 0 - Left
# printer.send_line("Left aligned")
# printer.send_text("\x1B\x61\x01") # ESC a 1 - Center
# printer.send_line("Centered")
# printer.send_text("\x1B\x61\x02") # ESC a 2 - Right
# printer.send_line("Right aligned")
# printer.send_text("\x1B\x61\x00") # Reset to left

# Size test: GS ! n — bits 0-3 = height, bits 4-7 = width (0-7 for 1x-8x)
(1..8).each do |size|
  n = ((size - 1) << 4) | (size - 1) # equal width and height
  printer.send_text("\x1D\x21" + n.chr)
  printer.send_line("#{size}x#{size}")
end
printer.send_text("\x1D\x21\x00") # reset to 1x1

printer.cut

puts "Done!"
