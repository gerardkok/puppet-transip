require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'puppet_x', 'transip', 'client.rb'))

Puppet::Type.newtype(:dns_record) do

  @doc = "Manage creation/deletion of DNS records."

  ensurable

  newparam(:name, :namevar => true) do
    desc "Default namevar"
  end

  newproperty(:fqdn) do
    desc "The fully qualified record."
  end

  newproperty(:type) do
    desc "The type of DNS record."

    newvalues(:A, :AAAA, :CNAME, :MX, :NS, :TXT, :SRV)

    munge do |value|
      value.to_s
    end

    defaultto :A
  end

  newproperty(:content, :array_matching => :all) do
    desc "The content of the DNS record."

    validate do |value|
      fail 'The content of the record must not be blank' if value.empty?
    end

    def insync?(is)
      is.to_set == should.to_set
    end
  end

  newproperty(:ttl) do
    desc "The TTL of the DNS record. Defaults to 3600."

    munge do |value|
      value.to_i
    end

    validate do |value|
      fail 'TTL must be an integer' unless value.to_i.to_s == value.to_s
    end

    defaultto "3600"
  end

  autorequire(:file) do
    Transip::CREDENTIALS_FILE
  end

  def self.title_patterns
    [
      [ /^(([^\/]*)\/(.*))$/, [ [:name], [:fqdn], [:type] ] ],
      [ /^((.*))$/, [ [:name], [:fqdn] ] ],
    ]
  end

end
