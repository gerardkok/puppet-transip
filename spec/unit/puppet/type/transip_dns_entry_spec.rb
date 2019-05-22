require 'spec_helper'

describe Puppet::Type.type(:transip_dns_entry) do
  describe 'when validating attributes' do
    [:name, :content_handling].each do |param|
      it "has a #{param} parameter" do
        expect(described_class.attrtype(param)).to eq(:param)
      end
    end
    [:ensure, :fqdn, :type, :content, :ttl].each do |prop|
      it "has a #{prop} property" do
        expect(described_class.attrtype(prop)).to eq(:property)
      end
    end
  end

  describe 'ensure' do
    [:present, :absent].each do |value|
      it "supports #{value} as a value to ensure" do
        expect {
          described_class.new(
            name: 'host.example.com/A',
            ensure: value,
          )
        }.not_to raise_error
      end
    end

    it 'does not support other values' do
      expect {
        described_class.new(
          name: 'host.example.com/A',
          ensure: 'foo',
        )
      }.to raise_error(Puppet::Error, %r{Invalid value})
    end
  end

  describe 'title patterns' do
    it 'recognises the part before the slash as fqdn' do
      expect(
        described_class.new(name: 'host.example.com/A')[:fqdn],
      ).to eq('host.example.com')
    end

    it 'recognises the part after the slash as type' do
      expect(
        described_class.new(name: 'host.example.com/A')[:type],
      ).to eq('A')
    end
  end

  describe 'content' do
    it 'does not allow an empty string as content' do
      expect {
        described_class.new(
          name: 'host.example.com/A',
          content: '',
        )
      }.to raise_error(Puppet::Error, %r{An empty record is not allowed})
    end

    it 'does not allow an empty array as content' do
      expect {
        described_class.new(
          name: 'host.example.com/A',
          content: [],
        )
      }.to raise_error(Puppet::Error, %r{The content of the record must not be blank})
    end

    it 'allows a CNAME record with one content entry' do
      expect {
        described_class.new(
          name: 'host.example.com/A',
          content: 'record1',
        )
      }.not_to raise_error
    end

    it 'does not allow a CNAME record with multiple content entries' do
      expect {
        described_class.new(
          name: 'host.example.com/CNAME',
          content: ['record1', 'record2'],
        )
      }.to raise_error(Puppet::Error, %r{The content of a CNAME record cannot have multiple entries})
    end

    it 'allows an A record with multiple content entries' do
      expect {
        described_class.new(
          name: 'host.example.com/A',
          content: ['record1', 'record2'],
        )
      }.not_to raise_error
    end
  end

  describe 'ttl' do
    it 'only allows integers' do
      expect {
        described_class.new(
          name: 'host.example.com/A',
          ttl: 'foo',
        )
      }.to raise_error(Puppet::Error, %r{TTL must be an integer})
    end

    it 'munges strings to integers' do
      expect(described_class.new(name: 'host.example.com/A', ttl: '600')[:ttl]).to eq(600)
    end
  end
end
