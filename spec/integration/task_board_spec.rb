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
TaskBoard = Aver.domain("task-board") do
  action :create_task, payload: { title: String, status: String }
  action :move_task, payload: { title: String, status: String }
  query :task_details, payload: String, returns: Hash
  assertion :task_in_status, payload: { title: String, status: String }
end

# Adapter
TaskBoardAdapter = Aver.implement(TaskBoard, protocol: Aver.unit { Board.new }) do
  handle(:create_task) { |board, p| board.create(p[:title], status: p.fetch(:status, "backlog")) }
  handle(:move_task) { |board, p| board.move(p[:title], p[:status]) }
  handle(:task_details) { |board, p| board.get(p) }
  handle(:task_in_status) { |board, p|
    task = board.get(p[:title])
    raise "Task '#{p[:title]}' not found" unless task
    raise "Expected '#{p[:status]}', got '#{task[:status]}'" unless task[:status] == p[:status]
  }
end

Aver.configuration.adapters << TaskBoardAdapter

RSpec.describe "Task Board", aver: TaskBoard do

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
