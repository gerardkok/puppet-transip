require 'spec_helper'

describe Puppet::Type.type(:transip_dns_entry).provider(:api) do
  context 'instances' do
    it 'has an instance method' do
      expect(described_class).to respond_to(:instances)
    end
  end

  context 'prefetch' do
    it 'has a prefetch method' do
      expect(described_class).to respond_to(:prefetch)
    end
  end

  context 'no entries' do
    before(:each) do
      described_class.expects(:all_entries).returns Hash[]
    end
    it 'returns no instances' do
      expect(described_class.instances.size).to eq(0)
    end
  end

  context 'entryname strip domain' do
    let(:resource) do
      Puppet::Type.type(:transip_dns_entry).new(
        ensure: :present,
        name: 'www.example.com/A',
        ttl: 3600,
        content: ['192.0.2.1'],
        provider: described_class.name,
      )
    end
    let(:provider) { resource.provider }

    it 'strips domain' do
      expect(provider.entryname('www.example.com', 'example.com')).to eq('www')
    end
  end

  context 'entryname with naked domain' do
    let(:resource) do
      Puppet::Type.type(:transip_dns_entry).new(
        ensure: :present,
        name: 'example.com/MX',
        ttl: 3600,
        content: ['10 mail.example.com.'],
        provider: described_class.name,
      )
    end
    let(:provider) { resource.provider }

    it 'replaces domain' do
      expect(provider.entryname('example.com', 'example.com')).to eq('@')
    end
  end

  context 'fqdn' do
    it 'adds domain' do
      expect(described_class.fqdn('www', 'example.com')).to eq('www.example.com')
    end
    it 'replaces @' do
      expect(described_class.fqdn('@', 'example.com')).to eq('example.com')
    end
  end

  context 'to_instance, add domain' do
    let(:entry_in) do
      { name: 'www',
        content: '192.0.2.1',
        type: 'A',
        expire: '3600' }
    end
    let(:entry_out) do
      { name: 'www.example.com/A',
        fqdn: 'www.example.com',
        content: '192.0.2.1',
        type: 'A',
        expire: '3600' }
    end

    it 'adds domain' do
      expect(described_class.to_instance(entry_in, 'example.com')).to eq(entry_out)
    end
  end

  context 'to_instance, replace @' do
    let(:entry_in) do
      { name: '@',
        content: '10 mail.example.com.',
        type: 'MX',
        expire: '3600' }
    end
    let(:entry_out) do
      { name: 'example.com/MX',
        fqdn: 'example.com',
        content: '10 mail.example.com.',
        type: 'MX',
        expire: '3600' }
    end

    it 'adds domain' do
      expect(described_class.to_instance(entry_in, 'example.com')).to eq(entry_out)
    end
  end

  context 'collapsed_content' do
    let(:entry1) do
      { name: '@',
        content: 'text1',
        type: 'TXT',
        expire: '3600' }
    end
    let(:entry2) do
      { name: '@',
        content: 'text2',
        type: 'TXT',
        expire: '3600' }
    end
    let(:entry_out) do
      { name: 'example.com/TXT',
        fqdn: 'example.com',
        content: %w[text1 text2],
        type: 'TXT',
        expire: '3600' }
    end

    it 'collapses content' do
      expect(described_class.collapsed_content([entry1, entry2], 'example.com')).to eq([entry_out])
    end
  end

  context 'collapsed_instances' do
    let(:com1) do
      { name: '@',
        content: 'text1',
        type: 'TXT',
        expire: '3600' }
    end
    let(:com2) do
      { name: '@',
        content: 'text2',
        type: 'TXT',
        expire: '3600' }
    end
    let(:eu1) do
      { name: '@',
        content: 'text1',
        type: 'TXT',
        expire: '3600' }
    end
    let(:eu2) do
      { name: '@',
        content: 'text2',
        type: 'TXT',
        expire: '3600' }
    end
    let(:entries) do
      ['example.com', [com1, com2], 'example.eu', [eu1, eu2]]
    end
    let(:com_out) do
      { name: 'example.com/TXT',
        fqdn: 'example.com',
        content: %w[text1 text2],
        type: 'TXT',
        expire: '3600' }
    end
    let(:eu_out) do
      { name: 'example.eu/TXT',
        fqdn: 'example.eu',
        content: %w[text1 text2],
        type: 'TXT',
        expire: '3600' }
    end

    before(:each) do
      described_class.expects(:all_entries).returns Hash[*entries]
    end
    it 'collapses instance' do
      expect(described_class.collapsed_instances).to eq([com_out, eu_out])
    end
  end

  context 'one entry' do
    let(:entry) do
      { name: 'host',
        content: '192.0.2.1',
        type: 'A',
        expire: '3600' }
    end
    let(:entries) do
      ['example.com', [entry]]
    end

    before :each do
      described_class.expects(:all_entries).returns Hash[*entries]
    end
    it 'returns one instance' do
      expect(described_class.instances.size).to eq(1)
    end
    it 'returns the instance host.example.com/A' do
      expect(described_class.instances[0].instance_variable_get('@property_hash')).to eq(
        ensure: :present,
        name: 'host.example.com/A',
        fqdn: 'host.example.com',
        content: ['192.0.2.1'],
        type: 'A',
        ttl: '3600',
      )
    end
  end

  context 'managed domain' do
    let(:resource) do
      Puppet::Type.type(:transip_dns_entry).new(
        ensure: :present,
        name: 'www.example.com/A',
        ttl: 3600,
        content: ['192.0.2.1'],
        provider: described_class.name,
      )
    end
    let(:provider) { resource.provider }

    before(:each) do
      provider.expects(:domain_names).returns ['example.com']
    end
    it 'matches domain' do
      expect(provider.domain).to eq('example.com')
    end
  end

  context 'unmanaged domain' do
    let(:resource) do
      Puppet::Type.type(:transip_dns_entry).new(
        ensure: :present,
        name: 'www.example.eu/A',
        ttl: 3600,
        content: ['192.0.2.1'],
        provider: described_class.name,
      )
    end
    let(:provider) { resource.provider }

    before :each do
      provider.expects(:domain_names).returns ['example.com']
    end
    it 'does not match domain' do
      expect { provider.domain }.to raise_error(Puppet::Error, %r{cannot find domain matching})
    end
    it 'throws error when creating host.example.eu/A' do
      expect { provider.flush }.to raise_error(Puppet::Error, %r{cannot find domain matching})
    end
  end

  context 'two domains' do
    let(:resource) do
      Puppet::Type.type(:transip_dns_entry).new(
        ensure: :present,
        name: 'www.example.eu/A',
        ttl: 3600,
        content: ['192.0.2.1'],
        provider: described_class.name,
      )
    end
    let(:provider) { resource.provider }

    before(:each) do
      provider.expects(:domain_names).returns ['example.com', 'example.eu']
    end
    it 'matches domain' do
      expect(provider.domain).to eq('example.eu')
    end
  end

  context 'add one entry' do
    let(:resource) do
      Puppet::Type.type(:transip_dns_entry).new(
        ensure: :present,
        name: 'example.com/MX',
        ttl: 300,
        content: ['10 mail.example.com.'],
      )
    end
    let(:provider) do
      described_class.new(resource).tap do |p|
        p.instance_variable_set(:@property_hash, property_hash)
      end
    end
    let(:property_hash) do
      { ensure: :present }
    end
    let(:entry_present) do
      { name: 'host',
        content: '192.0.2.1',
        type: 'A',
        expire: 3600 }
    end
    let(:entry_added) do
      { name: '@',
        content: '10 mail.example.com.',
        type: 'MX',
        expire: 300 }
    end

    before(:each) do
      provider.expects(:domain_names).once.returns ['example.com']
      provider.expects(:entries).with('example.com').once.returns([entry_present])
      provider.expects(:set_entries).with('example.com', [entry_present, entry_added]).once
    end
    it 'does not raise error' do
      expect { provider.flush }.not_to raise_error
    end
  end

  context 'remove one entry' do
    let(:resource) do
      Puppet::Type.type(:transip_dns_entry).new(
        ensure: :absent,
        name: 'example.com/MX',
        ttl: 300,
        content: ['10 mail.example.com.'],
      )
    end
    let(:provider) do
      described_class.new(resource).tap do |p|
        p.instance_variable_set(:@property_hash, property_hash)
      end
    end
    let(:property_hash) do
      { ensure: :absent }
    end
    let(:entry_present) do
      { name: '@',
        content: '10 mail.example.com.',
        type: 'MX',
        expire: 300 }
    end

    before(:each) do
      provider.expects(:domain_names).once.returns ['example.com']
      provider.expects(:entries).with('example.com').once.returns([entry_present])
      provider.expects(:set_entries).with('example.com', []).once
    end
    it 'does not raise error' do
      expect { provider.flush }.not_to raise_error
    end
  end

  context 'change one entry' do
    let(:resource) do
      Puppet::Type.type(:transip_dns_entry).new(
        ensure: :present,
        name: 'example.com/MX',
        ttl: 3600,
        content: ['10 mail.example.com.'],
        provider: described_class.name,
      )
    end
    let(:provider) { resource.provider }
    let(:entry_present) do
      { name: '@',
        content: '10 mail.example.com.',
        type: 'MX',
        expire: 300 }
    end
    let(:entry_changed) do
      { name: '@',
        content: '10 mail.example.com.',
        type: 'MX',
        expire: 3600 }
    end

    before(:each) do
      provider.expects(:domain_names).once.returns ['example.com']
      provider.expects(:entries).with('example.com').once.returns([entry_present])
      provider.expects(:set_entries).with('example.com', [entry_changed]).once
    end
    it 'does not raise error' do
      expect { provider.flush }.not_to raise_error
    end
  end

  context 'add content' do
    let(:resource) do
      Puppet::Type.type(:transip_dns_entry).new(
        ensure: :present,
        name: 'example.com/TXT',
        ttl: 3600,
        content: %w[text1 text2],
        provider: described_class.name,
      )
    end
    let(:provider) { resource.provider }
    let(:entry_present) do
      { name: '@',
        content: 'text1',
        type: 'TXT',
        expire: 3600 }
    end
    let(:entry_added) do
      { name: '@',
        content: 'text2',
        type: 'TXT',
        expire: 3600 }
    end

    before(:each) do
      provider.expects(:domain_names).once.returns ['example.com']
      provider.expects(:entries).with('example.com').once.returns([entry_present])
      provider.expects(:set_entries).with('example.com', [entry_present, entry_added]).once
    end
    it 'does not raise error' do
      expect { provider.flush }.not_to raise_error
    end
  end

  context 'remove content' do
    let(:resource) do
      Puppet::Type.type(:transip_dns_entry).new(
        ensure: :present,
        name: 'example.com/TXT',
        ttl: 3600,
        content: 'text1',
        provider: described_class.name,
      )
    end
    let(:provider) { resource.provider }
    let(:entry1) do
      { name: '@',
        content: 'text1',
        type: 'TXT',
        expire: 3600 }
    end
    let(:entry2) do
      { name: '@',
        content: 'text2',
        type: 'TXT',
        expire: 3600 }
    end

    before(:each) do
      provider.expects(:domain_names).once.returns ['example.com']
      provider.expects(:entries).with('example.com').once.returns([entry1, entry2])
      provider.expects(:set_entries).with('example.com', [entry1]).once
    end
    it 'does not raise error' do
      expect { provider.flush }.not_to raise_error
    end
  end

  context 'chnage content' do
    let(:resource) do
      Puppet::Type.type(:transip_dns_entry).new(
        ensure: :present,
        name: 'example.com/TXT',
        ttl: 3600,
        content: %w[text1 text3],
        provider: described_class.name,
      )
    end
    let(:provider) { resource.provider }
    let(:entry1) do
      { name: '@',
        content: 'text1',
        type: 'TXT',
        expire: 3600 }
    end
    let(:entry2) do
      { name: '@',
        content: 'text2',
        type: 'TXT',
        expire: 3600 }
    end
    let(:entry3) do
      { name: '@',
        content: 'text3',
        type: 'TXT',
        expire: 3600 }
    end

    before(:each) do
      provider.expects(:domain_names).once.returns ['example.com']
      provider.expects(:entries).with('example.com').once.returns([entry1, entry2])
      provider.expects(:set_entries).with('example.com', [entry1, entry3]).once
    end
    it 'does not raise error' do
      expect { provider.flush }.not_to raise_error
    end
  end
end
