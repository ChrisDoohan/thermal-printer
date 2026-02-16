class PrinterController < ApplicationController
  def index
    @connected = Printer.new.available?
  end

  def status
    render json: { connected: Printer.new.available? }
  end

  def print
    html = params[:html]

    if html.blank?
      render json: { error: "Nothing to print" }, status: :unprocessable_entity
      return
    end

    content = Content.find_or_create_by_body(html, "text")
    username = params[:username] || "anonymous"
    print_record = content.prints.create!(username: username)

    printer = Printer.new
    printer.send_html(html)

    if params[:commit] == "print_and_cut"
      printer.cut
    else
      printer.flush
    end

    render json: {
      message: "Printed successfully!",
      entry: serialize_entry(content, print_record)
    }
  rescue Printer::NotAvailable => e
    render json: { error: e.message }, status: :service_unavailable
  end

  def cut
    Printer.new.cut
    render json: { message: "Paper cut!" }
  rescue Printer::NotAvailable => e
    render json: { error: e.message }, status: :service_unavailable
  end

  def prints
    entries = Content
      .joins(:prints)
      .select("contents.*, prints.username AS last_username, prints.created_at AS last_printed_at")
      .order("prints.created_at DESC")
      .group("contents.id")
      .having("prints.created_at = MAX(prints.created_at)")

    render json: entries.map { |c|
      {
        id: c.id,
        content_type: c.content_type,
        preview: c.content_type == "text" ? strip_html(c.body) : nil,
        thumbnail: c.content_type == "image" ? c.thumbnail : nil,
        username: c.last_username,
        printed_at: c.last_printed_at,
        body: c.body
      }
    }
  end

  private

  def serialize_entry(content, print_record)
    {
      id: content.id,
      content_type: content.content_type,
      preview: content.content_type == "text" ? strip_html(content.body) : nil,
      thumbnail: content.content_type == "image" ? content.thumbnail : nil,
      username: print_record.username,
      printed_at: print_record.created_at,
      body: content.body
    }
  end

  def strip_html(html)
    ActionController::Base.helpers.strip_tags(html).truncate(200)
  end
end
