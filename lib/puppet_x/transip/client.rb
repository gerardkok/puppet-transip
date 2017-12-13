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

    def self.to_hash(entry, domain)
      fqdn = entry['name'] == '@' ? domain : "#{entry['name']}.#{domain}"
      { fqdn: fqdn, content: entry['content'], type: entry['type'], expire: entry['expire'] }
    end

    def self.to_entry(hsh, domain)
      name = hsh[:fqdn] == domain ? '@' : hsh[:fqdn].chomp(domain).chomp('.')
      Transip::DnsEntry.new(name: name, content: hsh[:content], type: hsh[:type], expire: hsh[:expire])
    end

    def self.entries(domain)
      domainclient.request(:get_info, domain_name: domain).to_hash[:domain]['dnsEntries'].map do |e|
        to_hash(e, domain)
      end
    end

    def self.entries_by_name(domain)
      domain['dnsEntries'].map { |e| to_hash(e, domain['name']) }.group_by { |h| "#{h[:fqdn]}/#{h[:type]}" }
    end

    def self.entries_in(domain)
      entries_by_name(domain).map do |_, v|
        v.each_with_object({}) do |e, memo|
          e.each_key { |k| k == :content ? (memo[k] ||= []) << e[k] : memo[k] ||= e[k] }
        end
      end
    end

    def self.all_entries
      dnsentries = domainclient.request(:batch_get_info, domain_names: domain_names)
      dnsentries.map(&:to_hash).inject([]) do |memo, domain|
        memo + entries_in(domain[:domain])
      end
    end

    def self.set_entries(domain, entries)
      dnsentries = entries.map { |e| to_entry(e, domain) }
      domainclient.request(:set_dns_entries, domain_name: domain, dns_entries: dnsentries)
    end
  end
end
