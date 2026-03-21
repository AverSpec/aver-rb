require "averspec"
require "averspec/protocol_http"
require "json"
require_relative "../domains/task_board"
require_relative "../lib/app"

# The HTTP adapter uses the TaskBoardApp as the server
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

ExampleTaskBoardHttpAdapter = Aver.implement(ExampleTaskBoard, protocol: TaskBoardHttpProtocol.new) do
  handle(:create_task) do |ctx, p|
    response = ctx.post("/tasks", { title: p[:title], status: p.fetch(:status, "backlog") })
    JSON.parse(response.body)
  end

  handle(:move_task) do |ctx, p|
    response = ctx.put("/tasks", { title: p[:title], status: p[:status] })
    JSON.parse(response.body)
  end

  handle(:task_details) do |ctx, p|
    response = ctx.get("/tasks?title=#{p}")
    JSON.parse(response.body, symbolize_names: true)
  end

  handle(:task_in_status) do |ctx, p|
    response = ctx.get("/tasks?title=#{p[:title]}")
    data = JSON.parse(response.body, symbolize_names: true)
    raise "Expected status '#{p[:status]}' but got '#{data[:status]}'" unless data[:status] == p[:status]
  end
end
