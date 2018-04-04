require 'yaml'
require 'puppet'
require File.expand_path(File.join(File.dirname(__FILE__), 'soap'))

module Transip
  class Client
    class << self
      def config_file
        @config_file ||= File.expand_path(File.join(Puppet.settings[:confdir], 'transip.yaml'))
      end

      def credentials
        @credentials ||= YAML.load_file(config_file)
      end

      def domainclient
        @domainclient ||= Transip::Soap.new(username: credentials['username'], key_file: credentials['key_file'], mode: :readwrite)
      end

      def domain_names
        @domain_names ||= domainclient.request(:get_domain_names)
      rescue Savon::SOAPFault
        raise Puppet::Error, 'Unable to get domain names'
      end

      def to_entry(dnsentry)
        %i[name content type expire].each_with_object({}) do |i, memo|
          memo[i] = dnsentry[i.to_s]
        end
      end

      def to_dnsentry(entry)
  #      Transip::DnsEntry.new(entry[:name], entry[:expire], entry[:type], entry[:content])
        entry.dup
      end

      def entries(domainname)
        dnsentries = domainclient.request(:get_info, domain_name: domainname)
        puts "dns entries: #{dnsentries.inspect}\n"
        dnsentries[:dns_entries]
  #    rescue Transip::ApiError
  #      raise Puppet::Error, "Unable to get entries for #{domainname}"
      end

      def to_array(domain)
        domain['dnsEntries'].map { |e| to_entry(e) }
      end

      def all_entries
        dnsentries = domainclient.request(:batch_get_info, domain_names: domain_names)
        dnsentries.each_with_object({}) do |domain, memo|
          memo[domain[:name]] = domain[:dns_entries]       
        end
      end

      def set_entries(domain, entries)
        dnsentries = entries.map { |e| to_dnsentry(e) }
        domainclient.request(:set_dns_entries, domain_name: domain, dns_entries: entries)
  #    rescue Transip::ApiError
  #      raise Puppet::Error, "Unable to set entries for #{domain}"
      end
    end
  end
end
