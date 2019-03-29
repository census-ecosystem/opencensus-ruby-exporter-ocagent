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


module OpenCensus
  module Trace
    module Exporters
      class OCAgent
        # An object that converts OpenCensus span data objects to OpenCensus
        # Agent Trace V1 protos
        #
        # @private
        #
        class Converter
          # OCAgent span protobuf alias.
          TraceProtos = OpenCensus::Proto::Trace::V1

          MAX_UINT64 = 0xffffffffffffffff

          # Create a converter
          #
          # @param [OpenCensus::Proto::Resource::V1::Resource] resource
          def initialize resource
            @resource = resource
          end

          # rubocop:disable Metrics/AbcSize, Metrics/MethodLength

          # Convert OpenCensus span object to OpenCensus Agent span proto object
          #
          # @param [OpenCensus::Trace::Span] obj OpenCensus span object
          # @return [OpenCensus::Proto::Trace::V1::Span] The generated proto
          #
          def convert_span obj
            TraceProtos::Span.new(
              trace_id: obj.trace_id,
              span_id: obj.span_id,
              parent_span_id: obj.parent_span_id || "",
              name: convert_truncatable_string(obj.name),
              kind: obj.kind,
              start_time: convert_time(obj.start_time),
              end_time: convert_time(obj.end_time),
              attributes: convert_attributes(
                obj.attributes,
                obj.dropped_attributes_count
              ),
              stack_trace: convert_stack_trace(
                obj.stack_trace,
                obj.dropped_frames_count,
                obj.stack_trace_hash_id
              ),
              time_events: convert_time_events(
                obj.time_events,
                obj.dropped_annotations_count,
                obj.dropped_message_events_count
              ),
              links: convert_links(obj.links, obj.dropped_links_count),
              status: convert_status(obj.status),
              same_process_as_parent_span: convert_bool(
                obj.same_process_as_parent_span
              ),
              child_span_count: convert_int32(obj.child_span_count),
              resource: @resource
            )
          end

          # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

          # Create a truncatable string proto.
          #
          # @param [String] str The string
          # @param [Integer] truncated_byte_count The number of bytes omitted.
          #   Defaults to 0.
          # @return [OpenCensus::Proto::Trace::V1::TruncatableStringg] The
          #  generated proto
          #
          def make_truncatable_string str, truncated_byte_count = 0
            TraceProtos::TruncatableString.new(
              value: str,
              truncated_byte_count: truncated_byte_count
            )
          end

          # Convert a truncatable string object.
          #
          # @param [OpenCensus::Trace::TruncatableString] obj OpenCensus
          #   truncatable string object
          # @return [OpenCensus::Proto::Trace::V1::TruncatableString] The
          #   generated proto
          #
          def convert_truncatable_string obj
            make_truncatable_string obj.value, obj.truncated_byte_count
          end

          # Convert a time object.
          #
          # @param [Time] time Ruby Time object
          # @return [Google::Protobuf::Timestamp] The generated proto
          def convert_time time
            Google::Protobuf::Timestamp.new seconds: time.to_i, nanos: time.nsec
          end

          # Convert a value that can be used for an attribute.
          #
          # @param [OpenCensus::Trace::TruncatableString, Integer, boolean]
          #   obj Object to convert
          # @return [OpenCensus::Proto::Trace::V1::AttributeValue] The
          #   generated proto
          #
          def convert_attribute_value obj
            case obj
            when OpenCensus::Trace::TruncatableString
              TraceProtos::AttributeValue.new(
                string_value: convert_truncatable_string(obj)
              )
            when Integer
              TraceProtos::AttributeValue.new int_value: obj
            when Float
              TraceProtos::AttributeValue.new double_value: obj
            when true, false
              TraceProtos::AttributeValue.new bool_value: obj
            end
          end

          # Convert an attributes proto
          #
          # @param [Hash] attributes The map of attribute values to convert
          # @param [Integer] dropped_attributes_count Number of dropped
          # @return [OpenCensus::Proto::Trace::V1::Span::Attributes] The
          #   generated proto
          #
          def convert_attributes attributes, dropped_attributes_count
            attribute_map = attributes.each_with_object({}) do |(k, v), r|
              r[k] = convert_attribute_value(v)
            end

            TraceProtos::Span::Attributes.new(
              attribute_map: attribute_map,
              dropped_attributes_count: dropped_attributes_count
            )
          end

          # Convert a single stack frame as a Thread::Backtrace::Location
          #
          # @param [Thread::Backtrace::Location] frame The backtrace element to
          #   convert
          # @return [OpenCensus::Proto::Trace::V1::StackTrace::StackFrame]
          #   The generated proto
          #
          def convert_stack_frame frame
            TraceProtos::StackTrace::StackFrame.new(
              function_name: make_truncatable_string(frame.label),
              file_name: make_truncatable_string(frame.path),
              line_number: frame.lineno
            )
          end

          # Convert backtrace to stack trace proto object.
          #
          # @param [Array<Thread::Backtrace::Location>] backtrace The backtrace
          #   elements
          # @param [Integer] dropped_frames_count Frames that were dropped
          # @param [Integer] stack_trace_hash_id Hash of the data
          # @return [OpenCensus::Proto::Trace::V1::StackTrace] The generated
          #   proto
          #
          def convert_stack_trace \
              backtrace,
              dropped_frames_count,
              stack_trace_hash_id
            frame_protos = backtrace.map { |frame| convert_stack_frame(frame) }
            frames_proto = TraceProtos::StackTrace::StackFrames.new(
              frame: frame_protos,
              dropped_frames_count: dropped_frames_count
            )

            TraceProtos::StackTrace.new(
              stack_frames: frames_proto,
              stack_trace_hash_id: stack_trace_hash_id & MAX_UINT64
            )
          end

          # Convert an annotation object
          #
          # @param [OpenCensus::Trace::Annotation] annotation The annotation
          #   object to convert
          # @return [OpenCensus::Proto::Trace::V1::Span::TimeEvent::Annotation]
          #   The generated proto
          #
          def convert_annotation annotation
            annotation_proto = TraceProtos::Span::TimeEvent::Annotation.new(
              description: convert_truncatable_string(annotation.description),
              attributes: convert_attributes(
                annotation.attributes,
                annotation.dropped_attributes_count
              )
            )
            TraceProtos::Span::TimeEvent.new(
              time: convert_time(annotation.time),
              annotation: annotation_proto
            )
          end

          # Convert a message event object
          #
          # @param [OpenCensus::Trace::MessageEvent] message_event The message
          #   event object to convert
          # @return [
          #   OpenCensus::Proto::Trace::V1::Span::TimeEvent::MessageEvent
          # ] The generated proto
          #
          def convert_message_event message_event
            msg_event_proto = TraceProtos::Span::TimeEvent::MessageEvent.new(
              type: message_event.type,
              id: message_event.id,
              uncompressed_size: message_event.uncompressed_size,
              compressed_size: message_event.compressed_size
            )
            TraceProtos::Span::TimeEvent.new(
              time: convert_time(message_event.time),
              message_event: msg_event_proto
            )
          end

          # Convert a list of time event objects
          #
          # @param [Array<OpenCensus::Trace::TimeEvent>] time_events The time
          #   event objects to convert
          # @param [Integer] dropped_annotations_count Number of dropped
          #   annotations
          # @param [Integer] dropped_message_events_count Number of dropped
          #   message events
          # @return [OpenCensus::Proto::Trace::V1::Span::TimeEvents] The
          #   generated proto
          #
          def convert_time_events \
              time_events,
              dropped_annotations_count,
              dropped_message_events_count
            time_event_protos = time_events.map do |time_event|
              case time_event
              when OpenCensus::Trace::Annotation
                convert_annotation time_event
              when OpenCensus::Trace::MessageEvent
                convert_message_event time_event
              else
                nil
              end
            end

            TraceProtos::Span::TimeEvents.new(
              time_event: time_event_protos.compact,
              dropped_annotations_count: dropped_annotations_count,
              dropped_message_events_count: dropped_message_events_count
            )
          end

          # Convert a link object
          #
          # @param [OpenCensus::Trace::Link] link The link object to convert
          # @return [OpenCensus::Proto::Trace::V1::Span::TimeEvents::Link] The
          #   generated proto
          #
          def convert_link link
            TraceProtos::Span::Link.new(
              trace_id: link.trace_id,
              span_id: link.span_id,
              type: link.type,
              attributes: convert_attributes(
                link.attributes,
                link.dropped_attributes_count
              )
            )
          end

          # Convert a list of link objects
          #
          # @param [Array<OpenCensus::Trace::Link>] links The link objects to
          #   convert
          # @param [Integer] dropped_links_count Number of dropped links
          # @return [OpenCensus::Proto::Trace::V1::Span::Link] The generated
          #   proto
          #
          def convert_links links, dropped_links_count
            link_protos = links.map { |link| convert_link link }

            TraceProtos::Span::Links.new(
              link: link_protos,
              dropped_links_count: dropped_links_count
            )
          end

          # Convert a status object
          #
          # @param [OpenCensus::Trace::Status, nil] status The status object to
          #   convert, or nil if absent
          # @return [OpenCensus::Proto::Trace::V1::Status, nil]
          #   The generated proto, or nil
          #
          def convert_status status
            return nil unless status

            TraceProtos::Status.new code: status.code, message: status.message
          end

          # Convert a nullable boolean object
          #
          # @param [boolean, nil] value The value to convert, or nil if absent
          # @return [Google::Protobuf::BoolValue, nil] The generated proto,
          # or nil
          #
          def convert_bool value
            return nil unless value

            Google::Protobuf::BoolValue.new value: value
          end

          # Convert a int32 object
          #
          # @param [Integer, nil] value The value to convert, or nil if absent
          # @return [Google::Protobuf::Int32Value, nil] Generated proto, or nil
          #
          def convert_int32 value
            return nil unless value

            Google::Protobuf::UInt32Value.new value: value
          end
        end
      end
    end
  end
end
