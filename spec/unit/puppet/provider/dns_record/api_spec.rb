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
      described_class.expects(:entries).returns []
    end
    it 'should return no resources' do
      expect(described_class.instances.size).to eq(0)
    end
  end

  context 'with one entry' do
    before :each do
      described_class.expects(:entries).returns [
        { name: 'host.example.com/A',
          fqdn: 'host.example.com',
          content: ['192.0.2.1'],
          type: 'A',
          ttl: '3600' }
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

  context 'entries with one entry' do
    before :each do
      described_class.expects(:domain_names).returns ['example.com']
      described_class.expects(:get_entries).with('example.com').returns [
        { 'name'    => 'host',
          'type'    => 'A',
          'content' => '192.0.2.1',
          'expire'  => '3600' }
      ]
    end
    it 'should return one resource' do
      expect(described_class.entries.size).to eq(1)
    end
    it 'should return the resource host.example.com/A' do
      expect(described_class.entries[0]).to eq(
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
      described_class.expects(:domain_names).returns ['example.com']
    end
    it 'should construct domains_re' do
      expect(provider.domains_re).to eq(/^.*(example\.com)$/)
    end
    it 'should not match domain' do
      expect { provider.domain }.to raise_error(Puppet::Error)
    end
    it 'should not construct hostname' do
      expect { provider.record }.to raise_error(Puppet::Error)
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
    before :each do
      described_class.expects(:domain_names).returns ['example.com', 'example.eu']
    end
    it 'should construct domains_re' do
      expect(provider.domains_re).to eq(/^.*(example\.com|example\.eu)$/)
    end
    it 'should match domain' do
      expect(provider.domain).to eq('example.eu')
    end
    it 'should construct hostname' do
      expect(provider.record).to eq('www')
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
      described_class.expects(:domain_names).twice.returns ['example.eu']
      described_class.expects(:get_entries).with('example.eu').once.returns []
      described_class.expects(:set_entries).once
    end
    it 'should not raise error' do
      expect { provider.flush }.to_not raise_error
    end
  end
end
