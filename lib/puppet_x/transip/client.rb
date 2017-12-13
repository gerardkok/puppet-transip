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
      domainclient.request(:get_domain_names)
    end

    def self.get_entries(domain)
      domainclient.request(:get_info, domain_name: domain).to_hash[:domain]['dnsEntries']
    end

    def self.all_entries
      domainclient.request(:batch_get_info, domain_names: domain_names).map(&:to_hash)
    end

    def self.set_entries(domain, entries)
      domainclient.request(:set_dns_entries, domain_name: domain, dns_entries: entries)
    end

    def self.record(fqdn, domain)
      fqdn == domain ? '@' : fqdn.chomp(domain).chomp('.')
    end

    def self.fqdn(record, domain)
      record == '@' ? domain : "#{record}.#{domain}"
    end

    def self.to_hash(entry, domain)
      fqdn = fqdn(entry['name'], domain)
      name = "#{fqdn}/#{entry['type']}"
      { name: name, fqdn: fqdn, content: entry['content'], type: entry['type'], ttl: entry['expire'] }
    end
  end
end
