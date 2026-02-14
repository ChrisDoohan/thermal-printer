require "bundler/setup"
require "escpos"
require 'debug'

class Printer
  DEVICE_PATH = "/dev/usb/lp0"

  def initialize
    @escpos = Escpos::Printer.new
  end

  def available?
    File.exist?(DEVICE_PATH) && File.writable?(DEVICE_PATH)
  end

  def send_text(text)
    @escpos << text
  end

  def cut
    @escpos << "\n\n\n\n\n\n"
    @escpos.partial_cut!
    write_to_device
  end

  def write_to_device
    File.open(DEVICE_PATH, "wb") { |f| f.write(@escpos.to_escpos) }
    @escpos = Escpos::Printer.new
  end
end

printer = Printer.new

puts "Printer available? #{printer.available?}"

unless printer.available?
  puts "Printer not found at #{Printer::DEVICE_PATH}"
  exit 1
end

# Cancel CJK mode (FS .) then set code page to CP850
printer.send_text("\x1C\x2E")
printer.send_text(Escpos::Helpers.set_printer_encoding(Escpos::CP_CP850))
printer.send_text("Saut\u00E9ed vegetables\n".encode("CP850"))

printer.send_text("Plain ASCII for comparison\n")
printer.cut

puts "Done!"
