require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'puppet_x', 'transip', 'client.rb'))

Puppet::Type.type(:dns_record).provide(:api) do
  confine feature: %i[transip transip_configured]

  mk_resource_methods
  def self.instances
    collapsed_instances.map do |e|
      new(ensure: :present, name: e[:name], fqdn: e[:fqdn], content: e[:content], type: e[:type], ttl: e[:expire])
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
    if @property_hash[:ensure] == :present
      @resource[:content].to_set.each do |c|
        entry = { fqdn: @resource[:fqdn], content: c, type: @resource[:type], expire: @resource[:ttl] }
        entries << entry
      end
    end
    set_entries(domain, entries)
    @property_hash = @resource.to_hash
  end

  def domain
    @domain ||= begin
      domains_re = /^.*(#{domain_names.join('|').gsub('.', '\.')})$/
      m = domains_re.match(@resource[:fqdn])
      raise Puppet::Error, "cannot find domain matching #{@resource[:name]}" if m.nil?
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

  # def self.entryname(entry)
  #   "#{entry[:fqdn]}/#{entry[:type]}"
  # end

  # def self.collapsed_entries
  #   all_entries.each { |e| e[:name] = entryname(e) }.group_by { |h| h[:name] }.map do |_, v|
  #     v.each_with_object({}) do |e, memo|
  #       e.each_key { |k| k == :content ? (memo[k] ||= []) << e[k] : memo[k] ||= e[k] }
  #     end
  #   end
  # end

  def self.to_instance(entry, domain)
    entry.tap do |e|
      e[:fqdn] = entry[:name] == '@' ? domain : "#{entry[:name]}.#{domain}"
      e[:name] = "#{e[:fqdn]}/#{entry[:type]}"
    end
  end

  def self.collapse_content(entries, domain)
    entries.each { |e| to_instance(e, domain) }.group_by { |h| h[:name] }.map do |_, v|
      v.each_with_object({}) do |e, memo|
        e.each_key { |k| k == :content ? (memo[k] ||= []) << e[k] : memo[k] ||= e[k] }
      end
    end
  end

  def self.collapsed_instances
    all_entries.each_with_object([]) do |(domain, entries), memo|
      memo + collapse_content(entries, domain)
    end
  end
end
