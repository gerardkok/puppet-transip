require 'spec_helper'

describe Transip::Soap do
  context 'camelize' do
    it 'should camelize' do
      expect(Transip::Soap.camelize(:get_domain_names)).to eq('getDomainNames')
    end
  end

  context 'array_to_indexed_hash' do
    it 'should be able to index empty array' do
      expect(Transip::Soap.array_to_indexed_hash([])).to eq({})
    end

    it 'should be able to index single element array' do
      expect(Transip::Soap.array_to_indexed_hash(['a'])).to eq({0 => 'a'})
    end

    it 'should be able to index multi element array' do
      expect(Transip::Soap.array_to_indexed_hash(['a', 'b', 'c'])).to eq({0 => 'a', 1 => 'b', 2 => 'c'})
    end
  end
end
