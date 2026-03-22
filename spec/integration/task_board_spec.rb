require "spec_helper"

# Simple in-memory task board for testing
class Board
  def initialize
    @tasks = {}
  end

  def create(title, status: "backlog")
    @tasks[title] = { title: title, status: status }
  end

  def move(title, status)
    raise "Task '#{title}' not found" unless @tasks[title]
    @tasks[title][:status] = status
  end

  def get(title)
    @tasks[title]
  end

  def all
    @tasks.values
  end
end

# Domain
class TaskBoardDomain < Aver::Domain
  domain_name "task-board"
  action :create_task, payload: { title: String, status: String }
  action :move_task, payload: { title: String, status: String }
  query :task_details, payload: String, returns: Hash
  assertion :task_in_status, payload: { title: String, status: String }
end

# Adapter
class TaskBoardUnitAdapter < Aver::Adapter
  domain TaskBoardDomain
  protocol :unit, -> { Board.new }

  def create_task(board, title:, status: "backlog", **_)
    board.create(title, status: status)
  end

  def move_task(board, title:, status:, **_)
    board.move(title, status)
  end

  def task_details(board, title)
    board.get(title)
  end

  def task_in_status(board, title:, status:, **_)
    task = board.get(title)
    raise "Task '#{title}' not found" unless task
    raise "Expected '#{status}', got '#{task[:status]}'" unless task[:status] == status
  end
end

Aver.register(TaskBoardUnitAdapter)

RSpec.describe "Task Board", aver: TaskBoardDomain do

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
    expect(entries[0].category).to eq("when")
    expect(entries[1].category).to eq("then")
    expect(entries.all? { |e| e.status == "pass" }).to be true
  end
end
