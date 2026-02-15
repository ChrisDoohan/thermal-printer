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

    printer = Printer.new
    printer.send_html(html)

    if params[:commit] == "print_and_cut"
      printer.cut
    else
      printer.flush
    end

    render json: { message: "Printed successfully!" }
  rescue Printer::NotAvailable => e
    render json: { error: e.message }, status: :service_unavailable
  end

  def cut
    Printer.new.cut
    render json: { message: "Paper cut!" }
  rescue Printer::NotAvailable => e
    render json: { error: e.message }, status: :service_unavailable
  end
end
