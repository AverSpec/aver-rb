require "averspec"
require_relative "../lib/board"
require_relative "../domains/task_board"

class ExampleTaskBoardUnitAdapter < Aver::Adapter
  domain ExampleTaskBoard
  protocol :unit, -> { Board.new }

  def create_task(board, title:, status: "backlog")
    board.create(title, status: status)
  end

  def move_task(board, title:, status:)
    board.move(title, status)
  end

  def task_details(board, title:)
    board.get(title)
  end

  def task_in_status(board, title:, status:)
    task = board.get(title)
    raise "Task '#{title}' not found" unless task
    raise "Expected '#{status}', got '#{task[:status]}'" unless task[:status] == status
  end
end
