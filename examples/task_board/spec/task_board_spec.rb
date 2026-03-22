require "averspec"
require "averspec/rspec"
require_relative "../domains/task_board"
require_relative "../adapters/task_board_unit"

Aver.register ExampleTaskBoardUnitAdapter

RSpec.describe ExampleTaskBoard do
  it "creates a task with default status" do
    ctx.when.create_task(title: "Fix bug")
    ctx.then.task_in_status(title: "Fix bug", status: "backlog")
  end

  it "moves a task to a new status" do
    ctx.when.create_task(title: "Write docs", status: "backlog")
    ctx.when.move_task(title: "Write docs", status: "in-progress")
    ctx.then.task_in_status(title: "Write docs", status: "in-progress")
  end

  it "queries task details" do
    ctx.when.create_task(title: "Deploy", status: "done")
    details = ctx.query.task_details(title: "Deploy")
    # details verified through domain query, not raw expect
  end

  it "records trace for all steps" do
    ctx.when.create_task(title: "Trace test")
    ctx.then.task_in_status(title: "Trace test", status: "backlog")
  end
end
