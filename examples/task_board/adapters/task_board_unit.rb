require "averspec"
require_relative "../lib/board"
require_relative "../domains/task_board"

ExampleTaskBoardUnitAdapter = Aver.implement(ExampleTaskBoard, protocol: Aver.unit { Board.new }) do
  handle(:create_task) { |board, p| board.create(p[:title], status: p.fetch(:status, "backlog")) }
  handle(:move_task) { |board, p| board.move(p[:title], p[:status]) }
  handle(:task_details) { |board, p| board.get(p) }
  handle(:task_in_status) do |board, p|
    task = board.get(p[:title])
    raise "Expected status '#{p[:status]}' but got '#{task[:status]}'" unless task[:status] == p[:status]
  end
end
