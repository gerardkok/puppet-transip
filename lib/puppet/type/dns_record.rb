require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'puppet_x', 'transip', 'client.rb'))

Puppet::Type.newtype(:dns_record) do
  @doc = 'Manage creation/deletion of DNS records.'

  ensurable

  newparam(:name, namevar: true) do
    desc 'Default namevar'
  end

  newproperty(:fqdn) do
    desc 'The fully qualified record.'
  end

  newproperty(:type) do
    desc 'The type of DNS record.'

    newvalues(:A, :AAAA, :CNAME, :MX, :NS, :TXT, :SRV)

    munge(&:to_s)

    defaultto :A
  end

  newproperty(:content, array_matching: :all) do
    desc 'The content of the DNS record.'

    validate do |value|
      fail 'An empty record is not allowed' if value.empty?
      fail 'The content of a CNAME record cannot have multiple entries' if value.length > 1 && @resource[:type] == 'CNAME'
    end

    def insync?(is)
      is.to_set == should.to_set
    end
  end

  newproperty(:ttl) do
    desc 'The TTL of the DNS record. Defaults to 3600.'

    munge(&:to_i)

    validate do |value|
      fail 'TTL must be an integer' unless value.to_i.to_s == value.to_s
    end

    defaultto '3600'
  end

  autorequire(:file) do
    Transip::Client.config_file
  end

  def self.title_patterns
    [
      [%r{^(([^/]*)/(.*))$}, [[:name], [:fqdn], [:type]]],
      [/^((.*))$/, [[:name], [:fqdn]]]
    ]
  end

  validate do
    fail('The content of the record must not be blank') if self[:content] && self[:content].empty?
  end
end
