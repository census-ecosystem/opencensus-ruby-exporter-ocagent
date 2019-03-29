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


require "helper"

describe OpenCensus::Trace::Exporters::OCAgent::TraceEnumeratorQueue do
  describe "#each_item" do
    it "add items and iterate" do
      enumerator = OpenCensus::Trace::Exporters::OCAgent::TraceEnumeratorQueue.new 0.1
      enumerator.push "item1"
      enumerator.push "item2"
      enumerator.push :STOP

      items = enumerator.each_item.map{ |v| v }
      items.length.must_equal 2
      items[0].must_equal "item1"
      items[1].must_equal "item2"
    end
  end
end
