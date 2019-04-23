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


require "opencensus/proto/trace/v1/trace_config_pb"

module OpenCensus
  module Trace
    module Exporters
      class OCAgent
        # Sampler
        #
        # Span sampler used to make decisions on span sampling
        #
        # @example Probability sampler
        #   require "opencensus-ocagent"
        #
        #   OpenCensus::Trace::Exporters::OCAgent::Sampler.create_probability(
        #     0.2
        #   )
        #
        # @example Probability sampler
        #   require "opencensus-ocagent"
        #
        #   OpenCensus::Trace::Exporters::OCAgent::Sampler.create_probability(
        #     0.2
        #   )
        #
        # @example Constant decision off sampler
        #   require "opencensus-ocagent"
        #
        #   OpenCensus::Trace::Exporters::OCAgent::Sampler \
        #     .create_off_constant_decision
        #
        # @example Constant decision on sampler
        #   require "opencensus-ocagent"
        #
        #   OpenCensus::Trace::Exporters::OCAgent::Sampler \
        #     .create_on_constant_decision
        #
        # @example Constant decision based on parent sampler
        #   require "opencensus-ocagent"
        #
        #   OpenCensus::Trace::Exporters::OCAgent::Sampler \
        #     .create_parent_constant_decision
        #
        # @example Rate limit sampler
        #   require "opencensus-ocagent"
        #
        #   OpenCensus::Trace::Exporters::OCAgent::Sampler.create_rate_limit 10
        #
        class Sampler
          # @private
          #
          # @param [OpenCensus::Proto::Trace::V1::ProbabilitySampler |
          #   OpenCensus::Proto::Trace::V1::ConstantSampler |
          #   OpenCensus::Proto::Trace::V1::RateLimitingSampler] proto Sampler
          #   proto object.
          def initialize proto
            @proto = proto
          end

          # Create probability sampler.
          #
          # Sampler that tries to uniformly sample traces with a given
          # probability.
          #
          # @param [Float] value Probability value.
          #   The desired probability of sampling. Must be within 0.0 and 1.0
          # @return [OpenCensus::Trace::Exporters::Sampler]
          # @raise [ArgumentError] if probability value not within 0.0 and 1.0
          #
          def self.create_probability value
            if value.negative? || value > 1
              raise ArgumentError, "value must be within 0.0 and 1.0"
            end

            proto = OpenCensus::Proto::Trace::V1::ProbabilitySampler.new(
              samplingProbability: value
            )
            new proto
          end

          # Create constant decision sampler that always off span sampling
          #
          # @return [OpenCensus::Trace::Exporters::Sampler]
          #
          def self.create_off_constant_decision
            proto = OpenCensus::Proto::Trace::V1::ConstantSampler.new(
              decision: :ALWAYS_OFF
            )
            new proto
          end

          # Create constant decision sampler that always on span sampling.
          #
          # @return [OpenCensus::Trace::Exporters::Sampler]
          #
          def self.create_on_constant_decision
            proto = OpenCensus::Proto::Trace::V1::ConstantSampler.new(
              decision: :ALWAYS_ON
            )
            new proto
          end

          # Create constant decision sampler that always follow the parent
          # Span's decision (off if no parent).
          #
          # @return [OpenCensus::Trace::Exporters::Sampler]
          #
          def self.create_parent_constant_decision
            proto = OpenCensus::Proto::Trace::V1::ConstantSampler.new(
              decision: :ALWAYS_PARENT
            )
            new proto
          end

          # Sampler that tries to sample with a rate per time window
          #
          # @param [Integer] value Rate per second
          # @return [OpenCensus::Trace::Exporters::Sampler]
          #
          def self.create_rate_limit value
            if value.negative?
              raise ArgumentError, "value must be greater then or equal to zero"
            end

            proto = OpenCensus::Proto::Trace::V1::RateLimitingSampler.new(
              qps: value
            )
            new proto
          end

          # @private
          #
          # Get sampler gRPC proto object
          #
          # @return [
          #   OpenCensus::Proto::Trace::V1::ProbabilitySampler,
          #   OpenCensus::Proto::Trace::V1::ConstantSampler,
          #   OpenCensus::Proto::Trace::V1::RateLimitingSampler
          # ]
          #
          def to_proto
            @proto
          end
        end
      end
    end
  end
end
