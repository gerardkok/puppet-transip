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

    def self.set_entries(domain, entries)
      domainclient.request(:set_dns_entries, domain_name: domain, dns_entries: entries)
    end
  end
end
