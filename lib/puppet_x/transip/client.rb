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

      def entries(domainname)
        domainclient.request(:get_info, domain_name: domainname)[:dns_entries]
      rescue Savon::SOAPFault
        raise Puppet::Error, "Unable to get entries for #{domainname}"
      end

      def all_entries
        dnsentries = domainclient.request(:batch_get_info, domain_names: domain_names)
        dnsentries.each_with_object({}) do |domain, memo|
          memo[domain[:name]] = domain[:dns_entries]       
        end
      end

      def set_entries(domain, entries)
        domainclient.request(:set_dns_entries, domain_name: domain, dns_entries: entries)
      rescue Savon::SOAPFault
        raise Puppet::Error, "Unable to set entries for #{domain}"
      end
    end
  end
end
