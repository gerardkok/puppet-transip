require 'yaml'
require 'puppet'
require File.expand_path(File.join(File.dirname(__FILE__), 'soap'))

module Transip
  class Client
    def self.config_file
      @config_file ||= File.expand_path(File.join(Puppet.settings[:confdir], 'transip.yaml'))
    end

    def self.credentials
      @credentials ||= YAML.load_file(config_file)
    end

    def self.domainclient
      @domainclient ||= Transip::Soap.new(username: credentials['username'], key_file: credentials['key_file'], mode: :readwrite)
    end

    def self.domain_names
      @domain_names ||= domainclient.request(:get_domain_names)
      puts "domain names: #{@domain_names}\n"
    rescue Savon::SOAPFault
      raise Puppet::Error, 'Unable to get domain names'
    end

    def self.to_entry(dnsentry)
      %i[name content type expire].each_with_object({}) do |i, memo|
        memo[i] = dnsentry[i.to_s]
      end
    end

    def self.to_dnsentry(entry)
#      Transip::DnsEntry.new(entry[:name], entry[:expire], entry[:type], entry[:content])
      entry.dup
    end

    def self.entries(domainname)
      to_array(domainclient.request(:get_info, domain_name: domainname).to_hash[:domain])
#    rescue Transip::ApiError
#      raise Puppet::Error, "Unable to get entries for #{domainname}"
    end

    def self.to_array(domain)
      domain['dnsEntries'].map { |e| to_entry(e) }
    end

    def self.all_entries
      puts "domain names in all_entries: #{domain_names}\n"
      options = { domain_names: domain_names }
      dnsentries = domainclient.request(:batch_get_info, options)
      puts "dnsentries: #{dnsentries.inspect}\n"
#      dnsentries = domainclient.request(:batch_get_info, domain_names: domain_names).map(&:to_hash)
#      dnsentries.each_with_object({}) do |domain, memo|
#        d = domain[:domain]
#        memo[d['name']] = to_array(d)
#      end
#    rescue Transip::ApiError
#      raise Puppet::Error, 'Unable to get entries for all domains'
      {}
    end

    def self.set_entries(domain, entries)
      dnsentries = entries.map { |e| to_dnsentry(e) }
      domainclient.request(:set_dns_entries, domain_name: domain, dns_entries: dnsentries)
#    rescue Transip::ApiError
#      raise Puppet::Error, "Unable to set entries for #{domain}"
    end
  end
end
