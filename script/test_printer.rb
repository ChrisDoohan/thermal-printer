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

printer.send_text("This is a test of printing without cutting.\n")
printer.write_to_device

printer.send_text("Hello from the Printer class!\n")
printer.send_text("This is a second write.\n")
printer.cut

puts "Done!"
