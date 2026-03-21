require "webrick"
require "json"
require_relative "board"

class TaskBoardApp
  attr_reader :board, :server

  def initialize(port: 0)
    @board = Board.new
    @port = port
  end

  def start
    @server = WEBrick::HTTPServer.new(
      Port: @port,
      BindAddress: "127.0.0.1",
      Logger: WEBrick::Log.new("/dev/null"),
      AccessLog: []
    )

    board = @board

    @server.mount_proc("/tasks") do |req, res|
      res["Content-Type"] = "application/json"

      case req.request_method
      when "GET"
        if req.query["title"]
          task = board.get(req.query["title"])
          if task
            res.body = JSON.generate(task)
          else
            res.status = 404
            res.body = '{"error":"not found"}'
          end
        else
          res.body = JSON.generate(board.all)
        end
      when "POST"
        body = JSON.parse(req.body || "{}")
        task = board.create(body["title"], status: body.fetch("status", "backlog"))
        res.status = 201
        res.body = JSON.generate(task)
      when "PUT"
        body = JSON.parse(req.body || "{}")
        begin
          board.move(body["title"], body["status"])
          task = board.get(body["title"])
          res.body = JSON.generate(task)
        rescue => e
          res.status = 404
          res.body = JSON.generate({ error: e.message })
        end
      end
    end

    @thread = Thread.new { @server.start }
    port
  end

  def port
    @server[:Port]
  end

  def stop
    @server&.shutdown
    @thread&.join(5)
  end
end
