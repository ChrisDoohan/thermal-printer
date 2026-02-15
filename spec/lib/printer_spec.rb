require "rails_helper"

RSpec.describe Printer do
  subject(:printer) { described_class.new }

  # Helper to extract the buffer contents after init sequence
  let(:init_bytes) { "\x1B\x40\x1C\x2E\x1B\x74\x06".b }

  def buffer
    printer.instance_variable_get(:@buffer)
  end

  def content_after_init
    buffer.delete_prefix(init_bytes)
  end

  describe "#initialize" do
    it "sends ESC @, FS ., and ESC t 6" do
      expect(buffer).to eq(init_bytes)
    end
  end

  describe "#available?" do
    it "returns true when device exists and is writable" do
      allow(File).to receive(:exist?).with(Printer::DEVICE_PATH).and_return(true)
      allow(File).to receive(:writable?).with(Printer::DEVICE_PATH).and_return(true)
      expect(printer.available?).to be true
    end

    it "returns false when device does not exist" do
      allow(File).to receive(:exist?).with(Printer::DEVICE_PATH).and_return(false)
      expect(printer.available?).to be false
    end
  end

  describe "#send_text" do
    it "encodes UTF-8 to CP1252" do
      printer.send_text("caf\u00E9")
      expect(content_after_init.bytes).to eq("caf\xE9".b.bytes)
    end

    it "replaces unencodable characters with ?" do
      printer.send_text("\u{1F600}")
      expect(content_after_init).to eq("?".b)
    end

    it "replaces common vulgar fractions with ASCII" do
      printer.send_text("½ cup ¼ tsp ¾ lb")
      expect(content_after_init).to eq("1/2 cup 1/4 tsp 3/4 lb".b)
    end

    it "replaces uncommon vulgar fractions with ASCII" do
      printer.send_text("⅓ and ⅔ and ⅛")
      expect(content_after_init).to eq("1/3 and 2/3 and 1/8".b)
    end

    it "replaces fraction slash with ASCII slash" do
      printer.send_text("1⁄2")
      expect(content_after_init).to eq("1/2".b)
    end
  end

  describe "#send_line" do
    it "appends text with a newline" do
      printer.send_line("hello")
      expect(content_after_init).to eq("hello\n".b)
    end
  end

  describe "#flush" do
    it "raises NotAvailable when device is not available" do
      allow(File).to receive(:exist?).with(Printer::DEVICE_PATH).and_return(false)
      expect { printer.flush }.to raise_error(Printer::NotAvailable)
    end
  end

  describe "formatting toggles" do
    it "bold_on/off sends correct ESC/POS bytes" do
      printer.bold_on
      printer.bold_off
      expect(content_after_init).to eq("\x1B\x45\x01\x1B\x45\x00".b)
    end

    it "uline_on/off sends single underline bytes" do
      printer.uline_on
      printer.uline_off
      expect(content_after_init).to eq("\x1B\x2D\x01\x1B\x2D\x00".b)
    end

    it "uline2_on/off sends double underline bytes" do
      printer.uline2_on
      printer.uline2_off
      expect(content_after_init).to eq("\x1B\x2D\x02\x1B\x2D\x00".b)
    end

    it "invert_on/off sends correct GS B bytes" do
      printer.invert_on
      printer.invert_off
      expect(content_after_init).to eq("\x1D\x42\x01\x1D\x42\x00".b)
    end
  end

  describe "alignment" do
    it "align_center sends ESC a 1" do
      printer.align_center
      expect(content_after_init).to eq("\x1B\x61\x01".b)
    end

    it "align_right sends ESC a 2" do
      printer.align_right
      expect(content_after_init).to eq("\x1B\x61\x02".b)
    end

    it "align_left sends ESC a 0" do
      printer.align_left
      expect(content_after_init).to eq("\x1B\x61\x00".b)
    end
  end

  describe "#set_size" do
    it "sets width and height equally" do
      printer.set_size(3)
      # n=3: (2 << 4) | 2 = 0x22
      expect(content_after_init).to eq("\x1D\x21\x22".b)
    end

    it "reset_size sets back to 0" do
      printer.reset_size
      expect(content_after_init).to eq("\x1D\x21\x00".b)
    end
  end

  describe "#send_html" do
    it "renders plain text" do
      printer.send_html("<p>hello</p>")
      expect(content_after_init).to eq("hello\n".b)
    end

    it "renders bold with <strong>" do
      printer.send_html("<p><strong>bold</strong></p>")
      expect(content_after_init).to eq(
        "\x1B\x45\x01bold\x1B\x45\x00\n".b
      )
    end

    it "renders italic with <em> as single underline" do
      printer.send_html("<p><em>italic</em></p>")
      expect(content_after_init).to eq(
        "\x1B\x2D\x01italic\x1B\x2D\x00\n".b
      )
    end

    it "renders <u> as double underline" do
      printer.send_html("<p><u>underlined</u></p>")
      expect(content_after_init).to eq(
        "\x1B\x2D\x02underlined\x1B\x2D\x00\n".b
      )
    end

    it "renders <mark> as inverted" do
      printer.send_html("<p><mark>highlight</mark></p>")
      expect(content_after_init).to eq(
        "\x1D\x42\x01highlight\x1D\x42\x00\n".b
      )
    end

    it "renders background-color span as inverted" do
      printer.send_html('<p><span style="background-color: rgb(0, 0, 0);">inverted</span></p>')
      expect(content_after_init).to eq(
        "\x1D\x42\x01inverted\x1D\x42\x00\n".b
      )
    end

    it "renders bold + inverted on the same element" do
      printer.send_html('<p><strong style="background-color: rgb(0, 0, 0);">both</strong></p>')
      expect(content_after_init).to eq(
        "\x1D\x42\x01\x1B\x45\x01both\x1B\x45\x00\x1D\x42\x00\n".b
      )
    end

    it "renders h1 with size 4 and bold" do
      printer.send_html("<h1>Title</h1>")
      expect(content_after_init).to eq(
        "\x1D\x21\x33\x1B\x45\x01Title\x1B\x45\x00\x1D\x21\x00\n".b
      )
    end

    it "renders h2 with size 3" do
      printer.send_html("<h2>Sub</h2>")
      expect(content_after_init).to eq(
        "\x1D\x21\x22\x1B\x45\x01Sub\x1B\x45\x00\x1D\x21\x00\n".b
      )
    end

    it "renders h3 with size 2" do
      printer.send_html("<h3>Small</h3>")
      expect(content_after_init).to eq(
        "\x1D\x21\x11\x1B\x45\x01Small\x1B\x45\x00\x1D\x21\x00\n".b
      )
    end

    it "renders <br> as newline" do
      printer.send_html("<p>line1<br>line2</p>")
      expect(content_after_init).to eq("line1\nline2\n".b)
    end

    it "renders center-aligned paragraph" do
      printer.send_html('<p class="ql-align-center">centered</p>')
      expect(content_after_init).to eq(
        "\x1B\x61\x01centered\n\x1B\x61\x00".b
      )
    end

    it "renders right-aligned paragraph" do
      printer.send_html('<p class="ql-align-right">right</p>')
      expect(content_after_init).to eq(
        "\x1B\x61\x02right\n\x1B\x61\x00".b
      )
    end

    it "handles nested formatting" do
      printer.send_html("<p><strong><u>bold underline</u></strong></p>")
      expect(content_after_init).to eq(
        "\x1B\x45\x01\x1B\x2D\x02bold underline\x1B\x2D\x00\x1B\x45\x00\n".b
      )
    end

    it "encodes accented characters to CP1252" do
      printer.send_html("<p>Saut\u00E9ed</p>")
      expect(content_after_init.bytes).to eq("Saut\xE9ed\n".b.bytes)
    end
  end
end
