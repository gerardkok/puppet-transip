Puppet::Type.newtype(:transip_dns_entry) do
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

    newvalues(:A, :AAAA, :CAA, :CNAME, :MX, :NS, :SRV, :TXT)

    munge(&:to_s)

    defaultto :A
  end

  newproperty(:content, array_matching: :all) do
    desc 'The content of the DNS record.'

    validate do |value|
      raise ArgumentError, 'An empty record is not allowed' if value.empty?
      raise ArgumentError, 'The content of a CNAME record cannot have multiple entries' if value.length > 1 && @resource[:type] == 'CNAME'
    end

    def insync?(is)
      is.to_set == should.to_set
    end
  end

  newproperty(:ttl) do
    desc 'The TTL of the DNS record. Defaults to 3600.'

    munge(&:to_i)

    validate do |value|
      raise ArgumentError, 'TTL must be an integer' unless value.to_i.to_s == value.to_s
    end

    defaultto '3600'
  end

  def self.title_patterns
    [
      [%r{^(([^/]*)/(.*))$}, [[:name], [:fqdn], [:type]]],
      [/^((.*))$/, [[:name], [:fqdn]]]
    ]
  end

  validate do
    raise ArgumentError, 'The content of the record must not be blank' if self[:content] && self[:content].empty?
  end
end
