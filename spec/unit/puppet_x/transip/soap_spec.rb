require 'spec_helper'

describe Transip::Soap do
  context 'camelize' do
    it 'should camelize' do
      expect(Transip::Soap.camelize(:get_domain_names)).to eq('getDomainNames')
    end
  end
end
