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

# test_lines = [
#   "àáâãäå ÀÁÂÃÄÅ",
#   "èéêë ÈÉÊË",
#   "ìíîï ÌÍÎÏ",
#   "òóôõö ÒÓÔÕÖ",
#   "ùúûü ÙÚÛÜ",
#   "ýÿ ÝŸ",
#   "ñ Ñ ç Ç",
#   "æ Æ ø Ø å Å",
#   "ß ð Ð þ Þ",
#   "½ ° € £ ¥ ¢",
# ]

# test_lines.each do |line|
#   printer.send_line(line)
# end

printer.send_text("Sentence 1")
printer.flush
printer.send_text("Sentence 2")
printer.flush

printer.cut

puts "Done!"
