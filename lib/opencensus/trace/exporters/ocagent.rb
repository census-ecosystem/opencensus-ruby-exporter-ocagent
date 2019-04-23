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


require "socket"
require "opencensus/proto/agent/trace/v1/trace_service_services_pb"
require "opencensus/trace/exporters/ocagent/trace_enumerator_queue"
require "opencensus/trace/exporters/ocagent/converter"

module OpenCensus
  ## OpenCensus Trace collects distributed traces
  module Trace
    ## Exporters for OpenCensus Trace.
    module Exporters
      # OpenCensus Agent exporter for Trace
      #
      # The OpenCensus Agent exporter exports captured OpenCensus Trace span to
      # OpenCensus Agent service.
      #
      class OCAgent
        # Default agent address
        # @return [String]
        DEFAULT_AGENT_SERVICE_ADDRESS = "localhost:55678"

        # Default metric resouce type.
        # @return [String]
        DEFAULT_GLOBAL_RESOURCE_TYPE = "global"

        # Default trace stream sleep delay time
        # @return [Float]
        DEFAULT_TRACE_STREAM_SLEEP_DELAY = 0.5

        # @private
        # Namespce alias for agent protobufs.
        AgentProto = OpenCensus::Proto::Agent

        # @return [String]
        attr_reader :service_name

        # OpenCensus Agent service network address.
        # @return [String]
        attr_reader :agent_service_address

        # gRPC channel auth credentials
        # @return [Symbol, GRPC::Core::ChannelCredentials]
        attr_reader :credentials

        # Node info. It contains process env info i.e PID, hostname
        # @return [OpenCensus::Proto::Agent::Common::V1::Node]
        attr_reader :node_info

        # Resource object with resource type and lables.
        # @return OpenCensus::Proto::Resource::V1::Resource
        attr_reader :resource

        # Trace stream sleep dealy if no item available in queue.
        # @return [Float]
        attr_reader :trace_stream_sleep_delay

        # @param [String] service_name Name of the service.
        # @param [String] agent_service_address OpenCensus Agent address.
        #   Default value is {DEFAULT_AGENT_SERVICE_ADDRESS}
        # @param [String | GRPC::Core::ChannelCredentials| nil] credentials
        #   The gRPC channel credentials PEM file path or channel credentials
        #   object. Default value is `:this_channel_is_insecure`,
        #   which explicitly indicates that the client should be created with
        #   an insecure connection.
        # @param [String] resource_type Resource type. Optional.
        #   Resource that is associated with each span which is going to export
        #   Default value is {DEFAULT_GLOBAL_RESOURCE_TYPE}
        # @param [Hash<String, String>] resource_labels
        #   Optional. Set of labels that describe the resource
        # @param [Integer] trace_stream_sleep_delay Time in seconds.
        #   Default value {DEFAULT_TRACE_STREAM_SLEEP_DELAY}
        #   Thread sleep time if no span available for export.
        def initialize \
            service_name:,
            agent_service_address: nil,
            credentials: nil,
            resource_type: nil,
            resource_labels: nil,
            trace_stream_sleep_delay: nil
          @service_name = service_name
          @agent_service_address =
            agent_service_address || DEFAULT_AGENT_SERVICE_ADDRESS

          if credentials.nil?
            @credentials = :this_channel_is_insecure
          elsif credentials.is_a? GRPC::Core::ChannelCredentials
            @credentials = credentials
          elsif credentials.is_a? String
            @credentials = GRPC::Core::ChannelCredentials.new credentials
          end

          @node_info = create_node_info
          @resource = create_resource(
            resource_type || DEFAULT_GLOBAL_RESOURCE_TYPE,
            labels: resource_labels
          )
          @trace_stream_sleep_delay =
            trace_stream_sleep_delay || DEFAULT_TRACE_STREAM_SLEEP_DELAY
          @stopped = true
          @trace_req_queue = nil
        end

        # Create the OpenCensus Agent trace service grpc client.
        # @return [OpenCensus::Proto::Agent::Trace::V1::TraceService::Stub]
        def client
          @client ||= AgentProto::Trace::V1::TraceService::Stub.new(
            agent_service_address,
            credentials
          )
        end

        # Create trace config proto.
        # Global configuration of the trace service.
        #
        # @param [Integer] max_attributes The max number of
        #   attributes per span. Optional
        # @param [Integer] max_annotations The max number of
        #   annotation events per span. Optional
        # @param [Integer] max_message_events The max number of
        #   message events per span. Optional
        # @param [Integer] max_linnks The global max number of link
        #   entries per span. Optional
        # @param [OpenCensus::Trace::Exporters::Sampler, nil] sampler
        #   The sampler used to make decisions on span sampling.
        #   See {Sampler} for different type of samplers.
        # @return [OpenCensus::Proto::Trace::V1::TraceConfig]
        #
        def create_trace_config \
            max_attributes: nil,
            max_annotations: nil,
            max_message_events: nil,
            max_linnks: nil,
            sampler: nil
          options = {
            max_number_of_attributes: max_attributes,
            max_number_of_annotations: max_annotations,
            max_number_of_message_events: max_message_events,
            max_number_of_links: max_linnks
          }

          sampler_proto = sampler ? sampler.to_proto : nil

          case sampler_proto
          when OpenCensus::Proto::Trace::V1::ProbabilitySampler
            options[:probability_sampler] = sampler_proto
          when OpenCensus::Proto::Trace::V1::ConstantSampler
            options[:constant_sampler] = sampler_proto
          when OpenCensus::Proto::Trace::V1::RateLimitingSampler
            options[:rate_limiting_sampler] = sampler_proto
          end

          options.delete_if!(&:nil?)
          OpenCensus::Proto::Trace::V1::TraceConfig.new options
        end

        # Stop the trace export stream.
        def stop
          @stopped = true
          @trace_req_queue&.push TraceEnumeratorQueue::SENTINEL
        end

        # Check exporter is stopped.
        #
        # @return [Boolean]
        def stopped?
          @stopped
        end

        # Start trace export stream.
        #
        # @return [Boolean] If steam is not started or stop returns true.
        #  If trace export stream alreay running return false.
        def start
          return false unless @stopped

          @trace_req_queue = TraceEnumeratorQueue.new @trace_stream_sleep_delay
          Thread.new { background_export_run }
          @stopped = false
          true
        end

        # Export spans to OpenCensus Agent service.
        #
        # @param [Array<OpenCensus::Trace::Span>] spans The captured spans to
        #   export to OpenCensus Agent service
        #
        def export spans
          return nil if spans.nil? || spans.empty?

          start unless @trace_req_queue

          return if stopped?

          converter = Converter.new @resource
          req = AgentProto::Trace::V1::ExportTraceServiceRequest.new(
            node: node_info,
            resource: resource,
            spans: spans.map { |span| converter.convert_span span }
          )
          @trace_req_queue.push req

          nil
        end

        private

        # rubocop:disable Metrics/MethodLength

        # Create node info proto.
        # @return [OpenCensus::Proto::Agent::Common::V1::Node]
        #
        def create_node_info
          time = Time.now.utc
          timestamp = Google::Protobuf::Timestamp.new(
            seconds: time.to_i,
            nanos: time.nsec
          )

          identifier = AgentProto::Common::V1::ProcessIdentifier.new(
            host_name: Socket.gethostname,
            pid: Process.pid,
            start_timestamp: timestamp
          )

          library_info = AgentProto::Common::V1::LibraryInfo.new(
            language: AgentProto::Common::V1::LibraryInfo::Language::RUBY,
            exporter_version: OpenCensus::OCAgent::VERSION,
            core_library_version: OpenCensus::VERSION
          )

          service_info = AgentProto::Common::V1::ServiceInfo.new(
            name: @service_name
          )

          OpenCensus::Proto::Agent::Common::V1::Node.new(
            identifier: identifier,
            library_info: library_info,
            service_info: service_info
          )
        end

        # rubocop:enable Metrics/MethodLength

        # Create resouce proto object.
        #
        # @param [String] type Resource type.
        #   Resource that is associated with each span which is going to export
        # @param [Hash<String, String>] labels Set of labels that describe the
        #   resource. Optional.
        # @return [OpenCensus::Proto::Resource::V1::Resource]
        #
        def create_resource type, labels: nil
          options = { type: type }
          options[:labels] = labels if labels
          OpenCensus::Proto::Resource::V1::Resource.new options
        end

        # Run exporter stream.
        def background_export_run
          client.export(@trace_req_queue.each_item).each {}
        rescue StandardError => err
          warn "Unable to export to OCAgent service: #{err.class} #{err}"
        ensure
          Thread.pass
        end
      end
    end
  end
end
