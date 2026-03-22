require "spec_helper"

# In-memory task board for OO adapter test
class OOBoard
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
end

# Domain using OO API
class OOTaskBoard < Aver::Domain
  domain_name "oo-task-board"

  action :create_task
  action :move_task
  query :task_details
  assertion :task_in_status
  assertion :task_count
end

# Adapter using OO API
class OOTaskBoardUnit < Aver::Adapter
  domain OOTaskBoard
  protocol :unit, -> { OOBoard.new }

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

  def task_count(board)
    # no-op for test
  end
end

RSpec.describe "OO Adapter (class-based)" do
  describe "class macros" do
    it "stores domain reference" do
      expect(OOTaskBoardUnit.domain).to eq(OOTaskBoard)
    end

    it "stores protocol name" do
      expect(OOTaskBoardUnit.protocol_name).to eq("unit")
    end

    it "stores protocol factory" do
      expect(OOTaskBoardUnit.protocol_factory).to respond_to(:call)
    end
  end

  describe "validation" do
    it "validates completeness" do
      expect { OOTaskBoardUnit.validate! }.not_to raise_error
    end

    it "detects missing handlers" do
      incomplete = Class.new(Aver::Adapter) do
        domain OOTaskBoard
        protocol :unit, -> { OOBoard.new }

        def create_task(board, **kwargs); end
      end
      expect { incomplete.validate! }.to raise_error(Aver::AdapterError, /Missing handlers/)
    end

    it "detects extra handlers" do
      extra = Class.new(Aver::Adapter) do
        domain OOTaskBoard
        protocol :unit, -> { OOBoard.new }

        def create_task(board, **kwargs); end
        def move_task(board, **kwargs); end
        def task_details(board, **kwargs); end
        def task_in_status(board, **kwargs); end
        def task_count(board); end
        def bogus(board); end
      end
      expect { extra.validate! }.to raise_error(Aver::AdapterError, /Extra handlers.*bogus/)
    end
  end

  describe "execution" do
    let(:adapter) { OOTaskBoardUnit.new }
    let(:board) { OOBoard.new }

    it "dispatches to instance method with keyword args" do
      adapter.execute(:create_task, board, { title: "Fix bug" })
      expect(board.get("Fix bug")).not_to be_nil
    end

    it "dispatches with nil payload" do
      board.create("Test")
      expect { adapter.execute(:task_count, board) }.not_to raise_error
    end

    it "returns method result" do
      board.create("Lookup")
      result = adapter.execute(:task_details, board, { title: "Lookup" })
      expect(result[:title]).to eq("Lookup")
    end
  end

  describe "Aver::Adapt alias" do
    it "is the same class as Aver::Adapter" do
      expect(Aver::Adapt).to equal(Aver::Adapter)
    end

    it "works as a base class" do
      klass = Class.new(Aver::Adapt) do
        domain OOTaskBoard
        protocol :unit, -> { OOBoard.new }
        def create_task(b, **kw); end
        def move_task(b, **kw); end
        def task_details(b, **kw); end
        def task_in_status(b, **kw); end
        def task_count(b); end
      end
      expect { klass.validate! }.not_to raise_error
    end
  end

  describe "configuration registration" do
    before(:each) { Aver.configuration.reset! }
    after(:each) { Aver.configuration.reset! }

    it "registers via Aver.register" do
      expect { Aver.register(OOTaskBoardUnit) }.not_to raise_error
    end

    it "registers via config.register" do
      Aver.configure do |config|
        config.register OOTaskBoardUnit
      end
      found = Aver.configuration.find_adapters(OOTaskBoard)
      expect(found.length).to eq(1)
    end

    it "finds class-based adapters for domain" do
      Aver.register(OOTaskBoardUnit)
      found = Aver.configuration.find_adapters(OOTaskBoard)
      expect(found.length).to eq(1)
      expect(found[0]).to eq(OOTaskBoardUnit)
    end
  end
end
