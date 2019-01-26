# frozen_string_literal: true

# Copyright 2019 Google LLC
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


expand :clean, paths: ["pkg", "doc", ".yardoc", "tmp"]

expand :minitest, libs: ["lib", "test"], files: ["test/**/*_test.rb"]

expand :rubocop

expand :yardoc do |t|
  t.generate_output_flag = true
  t.fail_on_warning = true
  t.fail_on_undocumented_objects = true
end

expand :gem_build

expand :gem_build, name: "release", push_gem: true

tool "ci" do
  desc "Run all CI checks"

  long_desc "The CI tool runs all CI checks for the gem, including unit" \
            " tests, rubocop, and documentation checks. It is useful for" \
            " running tests in normal development, as well as being the" \
            " entrypoint for CI systems such as Travis. Any failure will" \
            " result in a nonzero result code."

  include :exec
  include :terminal

  def run_stage name, tool
    if exec_tool(tool).success?
      puts "** #{name} passed\n\n", :green, :bold
    else
      puts "** CI terminated: #{name} failed!", :red, :bold
      exit 1
    end
  end

  def run
    run_stage "Tests", ["test"]
    run_stage "Style checker", ["rubocop"]
    run_stage "Docs generation", ["yardoc", "--no-output"]
  end
end
