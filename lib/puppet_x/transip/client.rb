require 'yaml'
require 'puppet'
require 'transip' if Puppet.features.transip?

module Transip
  class Client
    def self.config_file
      @config_file ||= File.expand_path(File.join(Puppet.settings[:confdir], 'transip.yaml'))
    end

    def self.credentials
      @credentials ||= YAML.load_file(config_file)
    end

    def self.domainclient
      @domainclient ||= Transip::DomainClient.new(username: credentials['username'], key_file: credentials['key_file'], ip: credentials['ip'], mode: :readwrite)
    end

    def self.domain_names
      @domain_names ||= domainclient.request(:get_domain_names)
    rescue Transip::ApiError
      raise Puppet::Error, 'Unable to get domain names'
    end

    def self.to_hash(entry, domain)
      fqdn = entry['name'] == '@' ? domain : "#{entry['name']}.#{domain}"
      { fqdn: fqdn, content: entry['content'], type: entry['type'], expire: entry['expire'] }
    end

    def self.to_entry(hsh, domain)
      name = hsh[:fqdn] == domain ? '@' : hsh[:fqdn].chomp(domain).chomp('.')
      Transip::DnsEntry.new(name, hsh[:expire], hsh[:type], hsh[:content])
    end

    def self.entries(domainname)
      to_array(domainclient.request(:get_info, domain_name: domainname).to_hash[:domain])
    rescue Transip::ApiError
      raise Puppet::Error, "Unable to get entries for #{domainname}"
    end

    def self.to_array(domain)
      domain['dnsEntries'].map { |e| to_hash(e, domain['name']) }
    end

    def self.all_entries
      entries = domainclient.request(:batch_get_info, domain_names: domain_names).map(&:to_hash)
      entries.inject([]) do |memo, domain|
        memo + to_array(domain[:domain])
      end
    rescue Transip::ApiError
      raise Puppet::Error, 'Unable to get entries for all domains'
    end

    def self.set_entries(domain, entries)
      dnsentries = entries.map { |e| to_entry(e, domain) }
      domainclient.request(:set_dns_entries, domain_name: domain, dns_entries: dnsentries)
    rescue Transip::ApiError
      raise Puppet::Error, "Unable to set entries for #{domain}"
    end
  end
end
