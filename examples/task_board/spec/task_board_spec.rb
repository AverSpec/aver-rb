require "averspec"
require "averspec/rspec"
require_relative "../domains/task_board"
require_relative "../adapters/task_board_unit"
require_relative "../adapters/task_board_http"

Aver.configuration.reset!
Aver.configuration.adapters << ExampleTaskBoardUnitAdapter
Aver.configuration.adapters << ExampleTaskBoardHttpAdapter

RSpec.describe "Task Board Example", aver: ExampleTaskBoard do
  aver_test "create a task with default status" do |ctx|
    ctx.when.create_task(title: "Fix bug")
    ctx.then.task_in_status(title: "Fix bug", status: "backlog")
  end

  aver_test "move a task to a new status" do |ctx|
    ctx.when.create_task(title: "Write docs", status: "backlog")
    ctx.when.move_task(title: "Write docs", status: "in-progress")
    ctx.then.task_in_status(title: "Write docs", status: "in-progress")
  end

  aver_test "query task details" do |ctx|
    ctx.when.create_task(title: "Deploy", status: "done")
    details = ctx.query.task_details("Deploy")
    expect(details[:status]).to eq("done")
  end

  aver_test "trace records all steps" do |ctx|
    ctx.when.create_task(title: "Trace test")
    ctx.then.task_in_status(title: "Trace test", status: "backlog")
    entries = ctx.trace
    expect(entries.length).to eq(2)
    expect(entries.all? { |e| e.status == "pass" }).to be true
  end
end
