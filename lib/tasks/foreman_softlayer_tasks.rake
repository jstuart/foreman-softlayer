# Tasks
namespace :foreman_softlayer do
  namespace :example do
    desc 'Example Task'
    task task: :environment do
      # Task goes here
    end
  end
end

# Tests
namespace :test do
  desc 'Test ForemanSoftlayer'
  Rake::TestTask.new(:foreman_softlayer) do |t|
    test_dir = File.join(File.dirname(__FILE__), '../..', 'test')
    t.libs << ['test', test_dir]
    t.pattern = "#{test_dir}/**/*_test.rb"
    t.verbose = true
  end
end

namespace :foreman_softlayer do
  task :rubocop do
    begin
      require 'rubocop/rake_task'
      RuboCop::RakeTask.new(:rubocop_foreman_softlayer) do |task|
        task.patterns = ["#{ForemanSoftlayer::Engine.root}/app/**/*.rb",
                         "#{ForemanSoftlayer::Engine.root}/lib/**/*.rb",
                         "#{ForemanSoftlayer::Engine.root}/test/**/*.rb"]
      end
    rescue
      puts 'Rubocop not loaded.'
    end

    Rake::Task['rubocop_foreman_softlayer'].invoke
  end
end

Rake::Task[:test].enhance do
  Rake::Task['test:foreman_softlayer'].invoke
end

load 'tasks/jenkins.rake'
if Rake::Task.task_defined?(:'jenkins:unit')
  Rake::Task['jenkins:unit'].enhance do
    Rake::Task['test:foreman_softlayer'].invoke
    Rake::Task['foreman_softlayer:rubocop'].invoke
  end
end
