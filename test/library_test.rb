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

describe OpenCensus::OCAgent do
  it "has a version number" do
    refute_nil OpenCensus::OCAgent::VERSION
  end

  it "export spans to agent service" do
    skip unless ENV["AGENT_SERVICE_ADDRESS"]

    exporter = OpenCensus::Trace::Exporters::OCAgent.new(
      service_name: "RubyOCAgent-Test",
      agent_service_address: ENV["AGENT_SERVICE_ADDRESS"]
    )
    OpenCensus::Trace.configure do |config|
      config.exporter = exporter
    end

    OpenCensus::Trace.start_request_trace do |root_context|
      OpenCensus::Trace.in_span("span1") do |span1|
        span1.put_attribute :data, "Outer span"
        sleep 0.1
        OpenCensus::Trace.in_span("span2") do |span2|
          span2.put_attribute :data, "Inner span"
          sleep 0.2
        end
        OpenCensus::Trace.in_span("span3") do |span3|
          span3.put_attribute :data, "Another inner span"
          sleep 0.1
        end
      end
      exporter.export root_context.build_contained_spans
    end
    OpenCensus::Trace.start_request_trace do |root_context|
      OpenCensus::Trace.in_span("span4") do |span4|
        span4.put_attribute :data, "Fast span"
      end
      exporter.export root_context.build_contained_spans
    end

    exporter.stop
    sleep 1
  end
end
