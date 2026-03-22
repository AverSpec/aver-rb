require "spec_helper"

# In-memory task board for OO integration test
class IntBoard
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

# OO Domain
class IntTaskBoard < Aver::Domain
  domain_name "int-task-board"

  action :create_task
  action :move_task
  query :task_details
  assertion :task_in_status
end

# OO Adapter
class IntTaskBoardUnit < Aver::Adapter
  domain IntTaskBoard
  protocol :unit, -> { IntBoard.new }

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

# Register
Aver.configuration.register(IntTaskBoardUnit)

RSpec.describe IntTaskBoard do
  # Manually build ctx for each test (class-based adapter)
  def make_ctx
    factory = IntTaskBoardUnit.protocol_factory
    protocol = Aver::UnitProtocol.new(factory, name: IntTaskBoardUnit.protocol_name.to_s)
    protocol_ctx = protocol.setup
    adapter_inst = IntTaskBoardUnit.new
    Aver::Context.new(domain: IntTaskBoard, adapter: adapter_inst, protocol_ctx: protocol_ctx, protocol: protocol)
  end

  it "creates a task in backlog" do
    ctx = make_ctx
    ctx.when.create_task(title: "Fix bug")
    ctx.then.task_in_status(title: "Fix bug", status: "backlog")
  end

  it "moves a task to a new status" do
    ctx = make_ctx
    ctx.when.create_task(title: "Write docs", status: "backlog")
    ctx.when.move_task(title: "Write docs", status: "in-progress")
    ctx.then.task_in_status(title: "Write docs", status: "in-progress")
  end

  it "queries task details" do
    ctx = make_ctx
    ctx.when.create_task(title: "Deploy", status: "done")
    details = ctx.query.task_details(title: "Deploy")
    expect(details[:status]).to eq("done")
  end

  it "records trace" do
    ctx = make_ctx
    ctx.when.create_task(title: "Trace test")
    ctx.then.task_in_status(title: "Trace test", status: "backlog")
    entries = ctx.trace
    expect(entries.length).to eq(2)
    expect(entries[0].category).to eq("when")
    expect(entries[1].category).to eq("then")
    expect(entries.all? { |e| e.status == "pass" }).to be true
  end

  it "records domain name in trace" do
    ctx = make_ctx
    ctx.when.create_task(title: "Name test")
    expect(ctx.trace[0].name).to eq("int-task-board.create_task")
  end
end
