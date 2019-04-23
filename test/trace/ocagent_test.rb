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

describe OpenCensus::Trace::Exporters::OCAgent do
  let(:service_name) { "ocagent-trace-exporter-service"}
  let(:trace_id) { "e8b86184bbb7f57f0aa3f6fd36c8f268" }
  let(:span1_id) { "4e24dd9d2724a35f" }
  let(:span2_id) { "140a0f209cfa84a6" }
  let(:truncatable_string) {
    OpenCensus::Trace::TruncatableString.new("Hello", truncated_byte_count: 0)
  }
  let(:span1){
    OpenCensus::Trace::Span.new(
      trace_id,
      span1_id,
      truncatable_string,
      Time.now,
      Time.now + 1
    )
   }
  let(:span2){
    OpenCensus::Trace::Span.new(
      trace_id,
      span2_id,
      truncatable_string,
      Time.now,
      Time.now + 1
    )
  }

  describe "#create" do
    it "create exporter instance with default values" do
      oc_agent = OpenCensus::Trace::Exporters::OCAgent.new service_name: service_name

      oc_agent.service_name.must_equal service_name
      oc_agent.agent_service_address.must_equal "localhost:55678"
      oc_agent.credentials.must_equal :this_channel_is_insecure

      identifier = oc_agent.node_info.identifier
      identifier.host_name.must_equal Socket.gethostname
      identifier.pid.must_equal Process.pid
      identifier.start_timestamp.seconds.must_be_close_to Time.now.utc.to_i

      library_info = oc_agent.node_info.library_info
      library_info.language.must_equal :RUBY
      library_info.exporter_version.must_equal OpenCensus::OCAgent::VERSION
      library_info.core_library_version.must_equal OpenCensus::VERSION

      oc_agent.node_info.service_info.name.must_equal service_name
    end

    it "create exporter instance with agent address" do
      agent_service_address = "test-ocagent-host:7777"
      oc_agent = OpenCensus::Trace::Exporters::OCAgent.new(
        service_name: service_name,
        agent_service_address: agent_service_address
      )

      oc_agent.agent_service_address.must_equal agent_service_address
    end

    it "create exporter instance with TLS credentials file" do
      oc_agent = OpenCensus::Trace::Exporters::OCAgent.new(
        service_name: service_name,
        credentials: "my-test.pem"
      )

      oc_agent.credentials.must_be_instance_of GRPC::Core::ChannelCredentials
    end
  end

  describe "#export" do
    it "export spans and stop exporter" do
      result = OpenStruct.new(requests: [], responses: [])
      mock_stub = Minitest::Mock.new(result)

      def mock_stub.export req, &block
        Enumerator.new do |y|
          req.each do |trace|
            self.requests << trace
            self.responses << OpenCensus::Proto::Agent::Trace::V1::ExportTraceServiceResponse.new
          end
        end
      end

      OpenCensus::Proto::Agent::Trace::V1::TraceService::Stub.stub(:new, mock_stub) do
        oc_agent = OpenCensus::Trace::Exporters::OCAgent.new(
          service_name: service_name
        )
        oc_agent.export [span1]
        oc_agent.export [span2]
        oc_agent.stop

        # Wait unitl request queue cleared.
        sleep 1
        oc_agent.stopped?.must_equal true
        result.requests.length.must_equal 2
        result.responses.length.must_equal 2

        oc_agent.export [span1]
        trace_req_queue = oc_agent.instance_variable_get("@trace_req_queue")
        trace_req_queue.instance_variable_get("@queue").empty?.must_equal true
      end
    end
  end
end
