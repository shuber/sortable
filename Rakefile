require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'
 
desc 'Default: run the sortable tests'
task :default => :test

namespace :test do
  desc 'Test the sortable gem/plugin with all active record versions >= 2.0.0'
  task :all do
    versions = `gem list`.match(/activerecord \((.+)\)/).captures[0].split(/, /).select { |v| v[0,1].to_i > 1 }
    versions.each do |version|
      puts "\n============================================================="
      puts "TESTING WITH ACTIVE RECORD VERSION #{version}\n\n"
      system "rake test ACTIVE_RECORD_VERSION=#{version}"
      puts "\n\n"
    end
  end
end

desc 'Test the sortable gem/plugin.'
Rake::TestTask.new(:test) do |t|
  t.libs << 'lib'
  t.pattern = 'test/*_test.rb'
  t.verbose = true
end
 
desc 'Generate documentation for the sortable gem/plugin.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'sortable'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README.rdoc')
  rdoc.rdoc_files.include('lib/**/*.rb')
end