require "optparse"
require "fileutils"

module Aver
  module CLI
    def self.run(argv = ARGV)
      command = argv.shift

      case command
      when "run"
        execute_run(argv)
      when "approve"
        execute_approve(argv)
      when "init"
        execute_init
      when "--help", "-h", nil
        print_help
      else
        $stderr.puts "Unknown command: #{command}"
        print_help
        exit 1
      end
    end

    def self.execute_run(argv)
      adapter = nil
      domain = nil
      remaining = []

      i = 0
      while i < argv.length
        case argv[i]
        when "--adapter"
          adapter = argv[i + 1]
          i += 2
        when "--domain"
          domain = argv[i + 1]
          i += 2
        else
          remaining << argv[i]
          i += 1
        end
      end

      ENV["AVER_ADAPTER"] = adapter if adapter
      ENV["AVER_DOMAIN"] = domain if domain

      rspec_args = ["bundle", "exec", "rspec", "--tag", "aver"]
      rspec_args.concat(remaining)
      exec(*rspec_args)
    end

    def self.execute_approve(argv)
      ENV["AVER_APPROVE"] = "1"
      execute_run(argv)
    end

    def self.execute_init
      puts "aver init -- scaffold a new domain\n\n"

      print "Domain name: "
      raw_name = $stdin.gets&.strip
      if raw_name.nil? || raw_name.empty?
        $stderr.puts "Error: domain name is required."
        exit 1
      end

      snake_name = _to_snake_case(raw_name)
      class_name = _to_class_name(snake_name)

      puts "\nProtocol options: unit, http"
      print "Protocol [unit]: "
      protocol = $stdin.gets&.strip&.downcase
      protocol = "unit" if protocol.nil? || protocol.empty?

      unless %w[unit http].include?(protocol)
        $stderr.puts "Error: unknown protocol '#{protocol}'. Choose from: unit, http"
        exit 1
      end

      puts "\nScaffolding '#{raw_name}' with #{protocol} protocol...\n\n"

      created = scaffold_domain(
        snake_name: snake_name,
        class_name: class_name,
        domain_label: raw_name,
        protocol: protocol
      )

      created.each { |path| puts "  created #{path}" }
      puts "\nDone."
    end

    def self.scaffold_domain(snake_name:, class_name:, domain_label:, protocol:)
      created = []

      # Domain file
      domain_dir = "domains"
      FileUtils.mkdir_p(domain_dir)
      domain_path = File.join(domain_dir, "#{snake_name}.rb")
      File.write(domain_path, <<~RUBY)
        class #{class_name} < Aver::Domain
          domain_name "#{domain_label}"

          action :create_#{snake_name}
          query :get_#{snake_name}
          assertion :#{snake_name}_exists
        end
      RUBY
      created << domain_path

      # Adapter file
      adapter_dir = "adapters"
      FileUtils.mkdir_p(adapter_dir)
      adapter_path = File.join(adapter_dir, "#{snake_name}_#{protocol}.rb")
      if protocol == "unit"
        File.write(adapter_path, <<~RUBY)
          class #{class_name}Unit < Aver::Adapter
            domain #{class_name}
            protocol :unit, -> { Object.new }

            def create_#{snake_name}(ctx, **kwargs)
            end

            def get_#{snake_name}(ctx)
              {}
            end

            def #{snake_name}_exists(ctx)
            end
          end
        RUBY
      else
        File.write(adapter_path, <<~RUBY)
          class #{class_name}Http < Aver::Adapter
            domain #{class_name}
            protocol Aver.http(base_url: "http://localhost:3000")

            def create_#{snake_name}(ctx, **kwargs)
              ctx.post("/#{snake_name}", kwargs)
            end

            def get_#{snake_name}(ctx)
              ctx.get("/#{snake_name}")
            end

            def #{snake_name}_exists(ctx)
              ctx.get("/#{snake_name}")
            end
          end
        RUBY
      end
      created << adapter_path

      # Spec file
      spec_dir = "spec"
      FileUtils.mkdir_p(spec_dir)
      spec_path = File.join(spec_dir, "#{snake_name}_spec.rb")
      File.write(spec_path, <<~RUBY)
        require "spec_helper"
        require_relative "../domains/#{snake_name}"
        require_relative "../adapters/#{snake_name}_#{protocol}"

        Aver.register #{class_name}Unit

        RSpec.describe #{class_name}, aver: #{class_name} do
          aver_test "create a #{snake_name}" do |ctx|
            ctx.when.create_#{snake_name}
            ctx.then.#{snake_name}_exists
          end
        end
      RUBY
      created << spec_path

      created
    end

    private

    def self._to_snake_case(name)
      name.strip.gsub(/[-\s]+/, "_").gsub(/([a-z0-9])([A-Z])/, '\1_\2').downcase
    end

    def self._to_class_name(snake)
      snake.split("_").map(&:capitalize).join
    end

    def self.print_help
      puts <<~HELP
        aver -- Domain-driven acceptance testing for Ruby

        Commands:
          run       Run tests via bundle exec rspec
          approve   Run tests in approval mode (AVER_APPROVE=1)
          init      Scaffold a new domain

        Options:
          --adapter NAME    Set AVER_ADAPTER env var
          --domain  NAME    Set AVER_DOMAIN env var
      HELP
    end
  end
end
