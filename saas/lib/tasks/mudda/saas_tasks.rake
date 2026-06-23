require "rake/testtask"

namespace :test do
  desc "Run tests for mudda-saas gem"
  Rake::TestTask.new(saas: :environment) do |t|
    t.libs << "test"
    t.test_files = FileList[Mudda::Saas::Engine.root.join("test/**/*_test.rb")]
    t.warning = false
  end
end
