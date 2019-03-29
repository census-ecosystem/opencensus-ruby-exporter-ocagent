# frozen_string_literal: true

# Copyright 2019 OpenCensus Authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


require "bundler/gem_tasks"
require "rake/testtask"
require "yard"

require "rubocop/rake_task"
RuboCop::RakeTask.new

Rake::TestTask.new :test do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
end

YARD::Rake::YardocTask.new do |t|
 t.files   = ['lib/**/*.rb']   # optional
 t.options = ['--output-dir', 'docs/api'] # optional
 t.stats_options = ['--list-undoc']         # optional
end

desc "Start an interactive shell."
task :console do
  require "irb"
  require "irb/completion"
  require "pp"

  $LOAD_PATH.unshift "lib"

  require "opencensus-ocagent"

  ARGV.clear
  IRB.start
end

task :default => [:test, :rubocop, :yard]
