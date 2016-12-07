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

end