require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'puppet_x', 'transip', 'client'))

Puppet::Type.type(:transip_dns_entry).provide(:api) do
  confine feature: [:savon, :transip_configured]

  mk_resource_methods
  def self.instances
    collapsed_instances.map do |e|
      new(ensure: :present, name: e[:name], fqdn: e[:fqdn], content: e[:content], type: e[:type], ttl: e[:expire])
    end
  end

  def self.prefetch(resources)
    instances.each do |prov|
      if (resource = resources[prov.name])
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

  def entryname(fqdn, domain)
    (fqdn == domain) ? '@' : fqdn.chomp(domain).chomp('.')
  end

  def flush
    entryname = entryname(@resource[:fqdn], domain)
    existing_entries = entries(domain)
    entries_to_keep = existing_entries.reject { |e| e[:name] == entryname && e[:type] == @resource[:type] }
    unless @property_hash[:ensure] == :absent
      content = content_of_entry(existing_entries, entryname)
      content.each do |c|
        entries_to_keep << { name: entryname, content: c, type: @resource[:type], expire: @resource[:ttl] }
      end
    end
    set_entries(domain, entries_to_keep)
    @property_hash = @resource.to_hash
  end

  def content_of_entry(entries, entryname)
    return @resource[:content].to_set if @resource[:content_handling] == 'inclusive'

    existing_content = entries.select { |e| e[:name] == entryname && e[:type] == @resource[:type] }.map { |e| e[:content] }
    (existing_content + @resource[:content]).to_set
  end

  def domain
    @domain ||= begin
      domains_re = %r{^.*?(#{domain_names.join('|').gsub('.', '\.')})$}
      m = domains_re.match(@resource[:fqdn])
      raise Puppet::Error, "cannot find domain matching #{@resource[:name]}" unless m

      m[1]
    end
  end

  def domain_names
    Transip::Client.domain_names
  end

  def entries(domain)
    Transip::Client.entries(domain)
  end

  def set_entries(domain, entries)
    Transip::Client.set_entries(domain, entries)
  end

  def self.all_entries
    Transip::Client.all_entries
  end

  def self.fqdn(entryname, domain)
    (entryname == '@') ? domain : "#{entryname}.#{domain}"
  end

  def self.to_instance(entry, domain)
    entry.tap do |e|
      e[:fqdn] = fqdn(entry[:name], domain)
      e[:name] = "#{e[:fqdn]}/#{entry[:type]}"
    end
  end

  def self.collapsed_content(entries, domain)
    entries.each { |e| to_instance(e, domain) }.group_by { |h| h[:name] }.map do |_, v|
      v.each_with_object({}) do |e, memo|
        e.each_key { |k| (k == :content) ? (memo[k] ||= []) << e[k] : memo[k] ||= e[k] }
      end
    end
  end

  def self.collapsed_instances
    all_entries.reduce([]) do |memo, (domain, entries)|
      memo + collapsed_content(entries, domain)
    end
  end
end
