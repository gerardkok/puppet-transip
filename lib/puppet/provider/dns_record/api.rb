require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'puppet_x', 'transip', 'client.rb'))

Puppet::Type.type(:dns_record).provide(:api) do
  confine feature: %i[transip transip_configured]

  mk_resource_methods
  def self.instances
    entries.collect do |e|
      new(ensure: :present, name: e[:name], fqdn: e[:fqdn], content: e[:content], type: e[:type], ttl: e[:ttl])
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
    entries = get_entries(domain).reject { |e| Transip::Client.fqdn(e['name'], domain) == @recource[:fqdn] && e['type'] == @resource[:type] }
    puts "entries at start:\n"
    entries.each { |e| puts "#{e}\n" }
    if @property_hash[:ensure] == :present
      @resource[:content].to_set.each do |c|
        entries << Transip::DnsEntry.new(Transip::Client.record(@resource[:fqdn], domain), @resource[:ttl], @resource[:type], c)
      end
    end
    puts "entries at end:\n"
    entries.each { |e| puts "#{e}\n" }
    set_entries(domain, entries)
    @property_hash = @resource.to_hash
  end

  def domains_re
    domains = domain_names.join('|').gsub('.', '\.')
    @domains_re ||= /^.*(#{domains})$/
  end

  def domain
    m = domains_re.match(@resource[:fqdn])
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

  def self.get_entries(domain)
    Transip::Client.get_entries(domain)
  rescue Transip::ApiError
    raise Puppet::Error, "Unable to get entries for #{domain}"
  end

  def get_entries(domain)
    self.class.get_entries(domain)
  end

  def self.set_entries(domain, entries)
    Transip::Client.set_entries(domain, entries)
  rescue Transip::ApiError
    raise Puppet::Error, "Unable to set entries for #{domain}"
  end

  def set_entries(domain, entries)
    self.class.set_entries(domain, entries)
  end

  def self.entries_by_name(domain)
    get_entries(domain).map { |e| Transip::Client.to_hash(e, domain) }.group_by { |h| h[:name] }
  end

  def self.entries_in(domain)
    entries_by_name(domain).map do |_, v|
      v.each_with_object({}) do |e, memo|
        e.each_key { |k| k == :content ? (memo[k] ||= []) << e[k] : memo[k] ||= e[k] }
      end
    end
  end

  def self.entries
    domain_names.inject([]) do |memo, d|
      memo + entries_in(d)
    end
  end
end
