require 'spec_helper'

describe Puppet::Type.type(:dns_record) do
  describe 'when validating attributes' do
    [ :name ].each do |param|
      it "should have a #{param} parameter" do
        expect(described_class.attrtype(param)).to eq(:param)
      end
    end
    [ :ensure, :fqdn, :type, :content, :ttl ].each do |prop|
      it "should have a #{prop} property" do
        expect(described_class.attrtype(prop)).to eq(:property)
      end
    end
  end

  describe 'ensure' do
    [ :present, :absent ].each do |value|
      it "should support #{value} as a value to ensure" do
        expect { described_class.new({
            :name   => 'host.example.com/A',
            :ensure => value,
          })}.to_not raise_error
      end
    end

    it "should not support other values" do
      expect { described_class.new({
          :name   => 'host.example.com/A',
          :ensure => 'foo',
        })}.to raise_error(Puppet::Error, /Invalid value/)
    end
  end

  describe 'title patterns' do
    it "should recognise the part before the slash as fqdn" do
      expect(described_class.new({
        :name => 'host.example.com/A'
      })[:fqdn]).to eq('host.example.com')
    end

    it "should recognise the part after the slash as type" do
      expect(described_class.new({
        :name => 'host.example.com/A'
      })[:type]).to eq('A')
    end
  end

  describe 'content' do
    it "should not allow an ampty string as content" do
      expect { described_class.new({
          :name    => 'host.example.com/A',
          :content => ''
        })}.to raise_error(Puppet::Error, /An empty record is not allowed/)
    end

    it "should not allow an ampty array as content" do
      expect { described_class.new({
          :name    => 'host.example.com/A',
          :content => []
        })}.to raise_error(Puppet::Error, /The content of the record must not be blank/)
    end

    it "should not allow a CNAME record with one content entry" do
      expect { described_class.new({
          :name    => 'host.example.com/A',
          :content => 'record1'
        })}.to_not raise_error
    end

    it "should not allow a CNAME record with multiple content entries" do
      expect { described_class.new({
          :name    => 'host.example.com/CNAME',
          :content => ['record1', 'record2']
        })}.to raise_error(Puppet::Error, /The content of a CNAME record cannot have multiple entries/)
    end

    it "should allow an A record with multiple content entries" do
      expect { described_class.new({
          :name    => 'host.example.com/A',
          :content => ['record1', 'record2']
        })}.to_not raise_error
    end
  end

  describe 'ttl' do
    it "should only allow integers" do
      expect { described_class.new({
          :name => 'host.example.com/A',
          :ttl  => 'foo'
        })}.to raise_error(Puppet::Error, /TTL must be an integer/)
    end
  end

end