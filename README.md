# averspec

Domain-driven acceptance testing for Ruby.

Same test, every adapter. Define behavior once, verify it at unit, HTTP, and browser levels.

## Install

```ruby
# Gemfile
gem "averspec"
```

## Quick Example

```ruby
require "averspec"

class TaskBoard < Aver::Domain
  domain_name "task-board"

  action :create_task
  assertion :task_in_status
end

class TaskBoardUnit < Aver::Adapter
  domain TaskBoard
  protocol :unit, -> { {} }

  def create_task(board, title:, status: "backlog")
    board[title] = status
  end

  def task_in_status(board, title:, status:)
    raise "expected #{status}" unless board[title] == status
  end
end

Aver.register TaskBoardUnit
```

```ruby
# spec/task_board_spec.rb
require "averspec/rspec"

RSpec.describe TaskBoard do
  it "creates a task in backlog" do
    ctx.when.create_task(title: "Fix bug")
    ctx.then.task_in_status(title: "Fix bug", status: "backlog")
  end
end
```

## CLI

```bash
aver run                    # run all specs
aver run --adapter unit     # filter by adapter
aver approve                # update approval baselines
aver init                   # scaffold a new domain
```

## Docs

[averspec.dev](https://averspec.dev) · [Architecture](https://github.com/AverSpec/aver) · [Example App](examples/task_board/)

## License

MIT
