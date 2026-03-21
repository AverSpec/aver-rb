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
