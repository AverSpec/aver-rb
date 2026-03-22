require "spec_helper"
require "averspec/cli"
require "tmpdir"
require "fileutils"

RSpec.describe "Aver::CLI.scaffold_domain" do
  let(:tmpdir) { Dir.mktmpdir("aver_init") }
  after { FileUtils.rm_rf(tmpdir) }

  it "creates domain, adapter, and spec files for unit protocol" do
    Dir.chdir(tmpdir) do
      created = Aver::CLI.scaffold_domain(
        snake_name: "task_board",
        class_name: "TaskBoard",
        domain_label: "task-board",
        protocol: "unit"
      )
      expect(created.length).to eq(3)
      expect(File.exist?("domains/task_board.rb")).to be true
      expect(File.exist?("adapters/task_board_unit.rb")).to be true
      expect(File.exist?("spec/task_board_spec.rb")).to be true
    end
  end

  it "generates valid Ruby in domain file" do
    Dir.chdir(tmpdir) do
      Aver::CLI.scaffold_domain(
        snake_name: "my_app",
        class_name: "MyApp",
        domain_label: "my-app",
        protocol: "unit"
      )
      content = File.read("domains/my_app.rb")
      expect(content).to include("class MyApp < Aver::Domain")
      expect(content).to include('domain_name "my-app"')
    end
  end

  it "converts snake_case correctly" do
    expect(Aver::CLI.send(:_to_snake_case, "TaskBoard")).to eq("task_board")
    expect(Aver::CLI.send(:_to_snake_case, "my-app")).to eq("my_app")
  end

  it "converts to class name correctly" do
    expect(Aver::CLI.send(:_to_class_name, "task_board")).to eq("TaskBoard")
    expect(Aver::CLI.send(:_to_class_name, "my_app")).to eq("MyApp")
  end
end
