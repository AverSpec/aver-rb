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
require "averspec/rspec"

TaskBoard = Aver.domain("task-board") do
  action :create_task, payload: Hash
  assertion :task_in_status, payload: Hash
end

adapter = Aver.implement(TaskBoard, protocol: Aver.unit { {} }) do
  handle(:create_task) { |board, p| board[p[:title]] = p[:status] || "backlog" }
  handle(:task_in_status) { |board, p|
    raise "expected #{p[:status]}" unless board[p[:title]] == p[:status]
  }
end

Aver.configure { |c| c.adapters = [adapter] }

RSpec.describe "Task Board", aver: TaskBoard do
  aver_test "create task in backlog" do |ctx|
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
