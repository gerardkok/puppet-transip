require 'spec_helper'

describe Puppet::Type.type(:dns_record).provider(:api) do
  describe 'instances' do
    it 'should have an instance method' do
      expect(described_class).to respond_to(:instances)
    end
  end

  describe 'prefetch' do
    it 'should have a prefetch method' do
      expect(described_class).to respond_to(:prefetch)
    end
  end

  context 'without entries' do
    before :each do
      described_class.expects(:all_entries).returns []
    end
    it 'should return no resources' do
      expect(described_class.instances.size).to eq(0)
    end
  end

  context 'with one entry' do
    before :each do
      described_class.expects(:all_entries).returns [
        { fqdn: 'host.example.com',
          content: '192.0.2.1',
          type: 'A',
          expire: '3600' }
      ]
    end
    it 'should return one resource' do
      expect(described_class.instances.size).to eq(1)
    end
    it 'should return the resource host.example.com/A' do
      expect(described_class.instances[0].instance_variable_get('@property_hash')).to eq(
        ensure: :present,
        name: 'host.example.com/A',
        fqdn: 'host.example.com',
        content: ['192.0.2.1'],
        type: 'A',
        ttl: '3600'
      )
    end
  end

  context 'unmanaged domain' do
    let(:resource) do
      Puppet::Type.type(:dns_record).new(
        ensure: :present,
        name: 'www.example.eu/A',
        ttl: 3600,
        content: ['192.0.2.1'],
        provider: described_class.name
      )
    end
    let(:provider) { resource.provider }
    before :each do
      provider.expects(:domain_names).returns ['example.com']
    end
    it 'should not match domain' do
      expect { provider.domain }.to raise_error(Puppet::Error)
    end
    it 'should error out when creating host.example.eu/A' do
      expect { provider.flush }.to raise_error(Puppet::Error)
    end
  end

  context 'two domains' do
    let(:resource) do
      Puppet::Type.type(:dns_record).new(
        ensure: :present,
        name: 'www.example.eu/A',
        ttl: 3600,
        content: ['192.0.2.1'],
        provider: described_class.name
      )
    end
    let(:provider) { resource.provider }
    before do
      provider.expects(:domain_names).returns ['example.com', 'example.eu']
    end
    it 'should match domain' do
      expect(provider.domain).to eq('example.eu')
    end
  end

  context 'flush' do
    let(:resource) do
      Puppet::Type.type(:dns_record).new(
        ensure: :present,
        name: 'www.example.eu/A',
        ttl: 3600,
        content: ['192.0.2.1'],
        provider: described_class.name
      )
    end
    let(:provider) { resource.provider }
    before do
      provider.expects(:domain_names).once.returns ['example.eu']
      provider.expects(:entries).with('example.eu').once.returns []
      provider.expects(:set_entries).with('example.eu', []).once
    end
    it 'should not raise error' do
      expect { provider.flush }.to_not raise_error
    end
  end

  context 'add one record' do
    let(:resource) do
      Puppet::Type.type(:dns_record).new(
        ensure: :present,
        name: 'example.com/MX',
        ttl: 300,
        content: ['10 mail.example.com.'],
        provider: described_class.name
      )
    end
    let(:provider) { resource.provider }
    let(:entry_present) do
      { fqdn: 'host.example.com',
        content: '192.0.2.1',
        type: 'A',
        expire: '3600' }
    end
    let(:entry_added) do
      { fqdn: 'example.com',
        content: '10 mail.example.com.',
        type: 'MX',
        expire: '300' }
    end
    before do
      provider.expects(:domain_names).once.returns ['example.com']
      provider.expects(:entries).with('example.com').once.returns([entry_present])
      provider.expects(:set_entries).with('example.com', [entry_present, entry_added]).once
    end
    it 'should not raise error' do
      expect { provider.flush }.to_not raise_error
    end
  end
end
