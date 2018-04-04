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
        @credentials ||= YAML.load_file(config_file).each_with_object({}) { |(k, v), memo| memo[k.to_sym] = v }
      end

      def domainclient
        puts "creds: #{credentials.inspect}\n"
        @domainclient ||= Transip::Soap.new(credentials)
      rescue ArgumentError => e
        raise Puppet::Error, "Cannot connect to endpoint: '#{e.message}'"
      end

      def domain_names
        @domain_names ||= domainclient.request(:get_domain_names)
      rescue Savon::SOAPFault => e
        raise Puppet::Error, "Unable to get domain names: '#{e.message}'"
      end

      def entries(domainname)
        domainclient.request(:get_info, domain_name: domainname)[:dns_entries]
      rescue Savon::SOAPFault => e
        raise Puppet::Error, "Unable to get entries for #{domainname}: '#{e.message}'"
      end

      def all_entries
        dnsentries = domainclient.request(:batch_get_info, domain_names: domain_names)
        dnsentries.each_with_object({}) do |domain, memo|
          memo[domain[:name]] = domain[:dns_entries]       
        end
      rescue Savon::SOAPFault => e
        raise Puppet::Error, "Unable to get entries for all domains: '#{e.message}'"
      end

      def set_entries(domain, entries)
        domainclient.request(:set_dns_entries, domain_name: domain, dns_entries: entries)
      rescue Savon::SOAPFault => e
        raise Puppet::Error, "Unable to set entries for #{domain}: '#{e.message}'"
      end
    end
  end
end
