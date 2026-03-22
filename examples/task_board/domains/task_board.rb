require "averspec"

class ExampleTaskBoard < Aver::Domain
  domain_name "task-board"

  action :create_task
  action :move_task
  query :task_details
  assertion :task_in_status
end
