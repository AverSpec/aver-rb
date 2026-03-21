require "averspec"

ExampleTaskBoard = Aver.domain("task-board") do
  action :create_task, payload: { title: String, status: String }
  action :move_task, payload: { title: String, status: String }
  query :task_details, payload: String, returns: Hash
  assertion :task_in_status, payload: { title: String, status: String }
end
