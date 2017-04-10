require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'puppet_x', 'transip', 'client.rb'))

Puppet::Type.type(:dns_record).provide(:api) do

  confine :feature => :transip

  mk_resource_methods
  def self.instances
    entries.collect do |e|
      new(:ensure => :present, :name => e[:name], :fqdn => e[:fqdn], :content => e[:content], :type => e[:type], :ttl => e[:ttl])
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
    entries = get_entries(domain)
    entries.reject! { |e| (e['name'] == record) && (e['type'] == @resource[:type])}
    if @property_hash[:ensure] == :present
      @resource[:content].to_set.each do |c|
        entries << Transip::DnsEntry.new(record, @resource[:ttl], @resource[:type], c)
      end
    end
    set_entries(domain, entries)
    @property_hash = @resource.to_hash
  end

  private

  def domains_re
    domains = domain_names.join('|').gsub('.', '\.')
    @domains_re ||= /^.*(#{domains})$/
  end

  def domain
    m = domains_re.match(@resource[:fqdn])
    raise Puppet::Error, "cannot find domain matching #{resource[:fqdn]}" if m.nil?
    @domain ||= m[1]
  end

  def record
    @record ||= @resource[:fqdn].chomp(domain).chomp('.')
  end

  def self.domain_names
    begin
      Transip::Client.get_domain_names
    rescue
      raise Puppet::Error, "Unable to get domain names"
    end
  end

  def domain_names
    self.class.domain_names
  end

  def self.get_entries(domain)
    begin
      Transip::Client.get_entries(domain)
    rescue
      raise Puppet::Error, "Unable to get entries for #{domain}"
    end
  end

  def get_entries(domain)
    self.class.get_entries(domain)
  end

  def self.set_entries(domain, entries)
    begin
      Transip::Client.set_entries(domain, entries)
    rescue
      raise Puppet::Error, "Unable to set entries for #{domain}"
    end
  end

  def set_entries(domain, entries)
    self.class.set_entries(domain, entries)
  end

  def self.entries
    r = []
    domain_names.each do |d|
      get_entries(d).each do |e|
        fqdn = e['name'] == '@' ? d : "#{e['name']}.#{d}"
        name = "#{fqdn}/#{e['type']}"
        if i = r.find { |f| f[:name] == name }
          i[:content] << e['content']
        else
          r << {:name => name, :fqdn => fqdn, :content => [e['content']], :type => e['type'], :ttl => e['expire']}
        end
      end
    end
    r
  end

end
