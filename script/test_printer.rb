require_relative "../lib/printer"

printer = Printer.new

puts "Printer available? #{printer.available?}"

unless printer.available?
  puts "Printer not found at #{Printer::DEVICE_PATH}"
  exit 1
end

html = <<~HTML
  <h1>Receipt Header</h1>
  <p>This is <strong>bold text</strong> and this is normal.</p>
  <p>This is <u>underlined</u> and <em>this is italic</em>.</p>
  <p>You can <strong>nest <u>bold and underline</u></strong> together.</p>
  <p><mark>Inverted text stands out!</mark></p>
  <h2>Medium heading</h2>
  <h3>Small heading</h3>
  <p>Sautéed vegetables for £5.50</p>
  <p class="ql-align-center">Centered text</p>
  <p class="ql-align-right">Right-aligned text</p>
HTML

printer.send_html(html)
printer.cut

puts "Done!"
