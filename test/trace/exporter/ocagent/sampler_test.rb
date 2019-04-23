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

describe OpenCensus::Trace::Exporters::OCAgent::Sampler do
  let(:sampler_class){
    OpenCensus::Trace::Exporters::OCAgent::Sampler
  }
  describe "#create_probability" do
    it "create sampler" do
      sampler = sampler_class.create_probability 0.1
      sampler.to_proto.samplingProbability.must_equal 0.1
    end

    it "raise error if probability less then 0 " do
      proc {
        sampler_class.create_probability(-0.1)
      }.must_raise ArgumentError
    end

    it "raise error if probability greater then 1 " do
      proc {
        sampler_class.create_probability 1.1
      }.must_raise ArgumentError
    end
  end

  describe "#create_off_constant_decision" do
    it "create sampler" do
      sampler = sampler_class.create_off_constant_decision
      sampler.to_proto.decision.must_equal :ALWAYS_OFF
    end
  end

  describe "#create_on_constant_decision" do
    it "create sampler" do
      sampler = sampler_class.create_on_constant_decision
      sampler.to_proto.decision.must_equal :ALWAYS_ON
    end
  end

  describe "#create_parent_constant_decision" do
    it "create sampler" do
      sampler = sampler_class.create_parent_constant_decision
      sampler.to_proto.decision.must_equal :ALWAYS_PARENT
    end
  end

  describe "#create_rate_limit" do
    it "create sampler" do
      sampler = sampler_class.create_rate_limit 100
      sampler.to_proto.qps.must_equal 100
    end

    it "raise error if value less then 0" do
      proc {
        sampler_class.create_probability(-10)
      }.must_raise ArgumentError
    end
  end
end
