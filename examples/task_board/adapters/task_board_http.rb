require "averspec"
require "json"
require_relative "../domains/task_board"
require_relative "../lib/app"

class TaskBoardHttpProtocol < Aver::Protocol
  def initialize
    super(name: "http")
    @app = nil
  end

  def setup
    @app = TaskBoardApp.new
    @app.start
    Aver::HttpContext.new(base_url: "http://127.0.0.1:#{@app.port}")
  end

  def teardown(ctx)
    @app&.stop
  end
end

class ExampleTaskBoardHttpAdapter < Aver::Adapter
  domain ExampleTaskBoard
  protocol :http, -> { nil }  # overridden by custom protocol below

  class << self
    def protocol_instance
      @protocol_instance ||= TaskBoardHttpProtocol.new
    end
  end

  def create_task(ctx, title:, status: "backlog")
    response = ctx.post("/tasks", { title: title, status: status })
    JSON.parse(response.body)
  end

  def move_task(ctx, title:, status:)
    response = ctx.put("/tasks", { title: title, status: status })
    JSON.parse(response.body)
  end

  def task_details(ctx, title:)
    response = ctx.get("/tasks?title=#{title}")
    JSON.parse(response.body, symbolize_names: true)
  end

  def task_in_status(ctx, title:, status:)
    response = ctx.get("/tasks?title=#{title}")
    data = JSON.parse(response.body, symbolize_names: true)
    raise "Expected '#{status}', got '#{data[:status]}'" unless data[:status] == status
  end
end
