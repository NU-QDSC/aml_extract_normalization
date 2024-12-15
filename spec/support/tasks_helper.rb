require 'rake'

# For specs with a type of 'task', the top level describe must be the task name with an optional "rake "-prefix
# Use task.invoke to run the task and its prerequisite tasks
# Use task.reenable to be able to invoke the same task multiple times
# Use task.execute to run the task
module TaskFormat
  extend ActiveSupport::Concern

  included do
    subject(:task) { Rake::Task[self.class.top_level_description.sub(/\Arake /, "")] }
  end
end

RSpec.configure do |config|
  config.define_derived_metadata(file_path: %r{/spec/lib/tasks/}) do |metadata|
    metadata[:type] = :task
  end
  config.include TaskFormat, type: :task
end