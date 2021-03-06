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
    end

    def insync?(is)
      return should.to_set.subset?(is.to_set) if @resource[:content_handling] == 'minimum'

      is.to_set == should.to_set
    end

    def change_to_s(currentvalue, newvalue)
      newvalue = (newvalue + currentvalue).uniq.sort if @resource[:content_handling] == 'minimum'
      super(currentvalue, newvalue)
    end

    defaultto []
  end

  newparam(:content_handling) do
    desc 'How content should be handled.'

    newvalues(:minimum, :inclusive)

    munge(&:to_s)

    defaultto :minimum
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
      [%r{^((.*))$}, [[:name], [:fqdn]]],
    ]
  end

  validate do
    raise ArgumentError, 'The content of the record must not be blank' if self[:content_handling] == 'inclusive' && self[:content].empty?
  end
end
