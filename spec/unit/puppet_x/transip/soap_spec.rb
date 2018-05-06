require 'spec_helper'

describe Transip::Soap do
  using Transip

  context 'camelize' do
    it 'camelizes' do
      expect(described_class.camelize(:get_domain_names)).to eq('getDomainNames')
    end
  end

  context 'to_indexed_hash' do
    it 'indexes empty array' do
      expect(described_class.to_indexed_hash([])).to eq({})
    end

    it 'indexes single element array' do
      expect(described_class.to_indexed_hash(['a'])).to eq(0 => 'a')
    end

    it 'indexes multi element array' do
      expect(described_class.to_indexed_hash(%w[a b c])).to eq(0 => 'a', 1 => 'b', 2 => 'c')
    end
  end

  context 'encode' do
    it 'encodes array' do
      expect(described_class.encode(%w[a b])).to eq(['0=a', '1=b'])
    end

    it 'encodes array of array' do
      expect(described_class.encode([%w[a b]])).to eq(['0[0]=a', '0[1]=b'])
    end

    it 'encodes hash' do
      expect(described_class.encode(name: 'a', type: 'b')).to eq(['name=a', 'type=b'])
    end

    it 'encodes array of hash' do
      expect(described_class.encode([{ name: 'a', type: 'b' }])).to eq(['0[name]=a', '0[type]=b'])
    end

    it 'encodes array of array of hash' do
      expect(described_class.encode([[{ name: 'a', type: 'b' }]])).to eq(['0[0][name]=a', '0[0][type]=b'])
    end
  end

  context 'serialize' do
    let(:output) { '0=a&1[0][name]=a&1[0][type]=b&__method=action&__service=service&__hostname=endpoint&__timestamp=1&__nonce=42' }

    it 'serializes' do
      expect(described_class.serialize(:action, 'service', 'endpoint', 1, 42, param1: 'a', param2: [{ name: 'a', type: 'b' }])).to eq(output)
    end
  end

  context 'to_soap' do
    let(:output) do
      { :item => { :content! => %w[a b], :'@xsi:type' => 'tns:String' },
        :'@xsi:type' => 'tns:ArrayOfString',
        :'@enc:arrayType' => 'tns:String[2]' }
    end

    it 'converts array to soap' do
      expect(%w[a b].to_soap).to eq(output)
    end
  end

  context 'single element array from_soap' do
    let(:input) do
      { :item => { :value => 'a', :'@xsi:type' => 'tns:String' },
        :'@xsi:type' => 'tns:ArrayOfString',
        :'@soap_enc:array_type' => 'tns:String[1]' }
    end

    it 'converts single element array' do
      expect(input.from_soap).to eq([{ value: 'a' }])
    end
  end

  context 'mutli element array from_soap' do
    let(:input) do
      { :item => [
        { :value => 'a', :'@xsi:type' => 'tns:String' },
        { :value => 'b', :'@xsi:type' => 'tns:String' },
      ],
        :'@xsi:type' => 'tns:ArrayOfString',
        :'@soap_enc:array_type' => 'tns:String[2]' }
    end

    it 'converts single element array' do
      expect(input.from_soap).to eq([{ value: 'a' }, { value: 'b' }])
    end
  end
end
