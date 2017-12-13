require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'puppet_x', 'transip', 'client.rb'))

Puppet::Type.type(:dns_record).provide(:api) do
  confine feature: %i[transip transip_configured]

  mk_resource_methods
  def self.instances
    all_entries.collect do |e|
      name = "#{e[:fqdn]}/#{e[:type]}"
      new(ensure: :present, name: name, fqdn: e[:fqdn], content: e[:content], type: e[:type], ttl: e[:expire])
    end
  end

  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name]
        resource.provider = prov
      end
    end
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def create
    @property_hash[:ensure] = :present
  end

  def destroy
    @property_hash[:ensure] = :absent
  end

  def flush
    entries = entries(domain).reject { |e| e[:fqdn] == @resource[:fqdn] && e[:type] == @resource[:type] }
    # puts "entries at start flush\n"
    # entries.each { |e| puts "entry: #{e}\n"}
    if @property_hash[:ensure] == :present
      @resource[:content].to_set.each do |c|
        entry = { fqdn: @resource[:fqdn], content: c, type: @resource[:type], expire: @resource[:ttl] }
        entries << entry
      end
    end
    # puts "entries at end flush\n"
    # entries.each { |e| puts "entry: #{e}\n"}
    set_entries(domain, entries)
    @property_hash = @resource.to_hash
  end

  def domain
    domainsre = /^.*(#{domain_names.join('|').gsub('.', '\.')})$/
    m = domainsre.match(@resource[:fqdn])
    raise Puppet::Error, "cannot find domain matching #{@resource[:fqdn]}" if m.nil?
    @domain ||= m[1]
  end

  def self.domain_names
    Transip::Client.domain_names
  rescue Transip::ApiError
    raise Puppet::Error, 'Unable to get domain names'
  end

  def domain_names
    self.class.domain_names
  end

  def self.entries(domain)
    Transip::Client.entries(domain)
  rescue Transip::ApiError
    raise Puppet::Error, "Unable to get entries for #{domain}"
  end

  def entries(domain)
    self.class.entries(domain)
  end

  def self.set_entries(domain, entries)
    Transip::Client.set_entries(domain, entries)
  rescue Transip::ApiError
    raise Puppet::Error, "Unable to set entries for #{domain}"
  end

  def set_entries(domain, entries)
    self.class.set_entries(domain, entries)
  end

  def self.all_entries
    Transip::Client.all_entries
  rescue Transip::ApiError
    raise Puppet::Error, 'Unable to get entries for all domains'
  end
end
