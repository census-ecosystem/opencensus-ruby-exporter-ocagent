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
        # TraceEnumeratorQueue insert trace request object in queue and send to
        # gRPC stream.
        #
        # @private
        #
        class TraceEnumeratorQueue
          # Stop queue item value
          SENTINEL = :STOP

          # @param [Float] delay Sleeping time when there no trace object to
          #   send.
          def initialize delay
            @queue = Queue.new
            @delay = delay
          end

          # Intsert trace object into queue.
          #
          # @param [OpenCensus::Proto::Agent::Trace::V1:: \
          #   ExportTraceServiceRequest] item
          def push item
            @queue << item
          end

          # Enumerator of queue items
          # @return [Enumerator]
          def each_item
            return enum_for(:each_item) unless block_given?

            loop do
              item = @queue.pop
              break if item == SENTINEL

              if item
                yield item
              else
                sleep @delay
              end
            end
          end
        end
      end
    end
  end
end
