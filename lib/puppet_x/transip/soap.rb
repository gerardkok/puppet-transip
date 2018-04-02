require 'uri'
require 'openssl'
require 'savon' if Puppet.features.savon?

module Transip
  class Soap
    API_VERSION ||= '5.6'.freeze
    ENDPOINT ||= 'api.transip.nl'.freeze
    API_SERVICE ||= 'DomainService'.freeze
    WSDL ||= "https://api.transip.nl/wsdl/?service=#{API_SERVICE}".freeze

    def initialize(options = {})
      @key = options[:key] || (options[:key_file] && File.read(options[:key_file]))
      @username = options[:username]
      raise ArgumentError, "The :username and :key options are required!" if @username.nil? or @key.nil?

      @mode = options[:mode] || :readonly

      @savon_options = {
        :wsdl => WSDL
      }

      @client = Savon::Client.new(@savon_options) do
        namespaces(
          "xmlns:enc" => "http://schemas.xmlsoap.org/soap/encoding/"
        )
      end
    end

    def camelize(word)
      parts = word.to_s.split("_")
      parts.first.downcase + parts[1..-1].map{ |p| p.capitalize }.join
    end
    
    def convert_array_to_hash(array)
      Hash[(0...array.size).zip(array)]
    end
    
    def urlencode(input)
      URI.encode_www_form_component(input).gsub('+', '%20').gsub('%7E', '~').gsub('*', '%2A')
    end

    def encode_params(params, prefix = nil)
      case params
      when Array
        p = convert_array_to_hash(params)
        encode_params(p, prefix)
      when Hash
        params.map do |key, value|
          k = urlencode(key)
          encoded_key = prefix.nil? ? k : "#{prefix}[#{k}]"
          case value
          when Hash, Array
            encode_params(value, encoded_key)
          else
            "#{encoded_key}=#{urlencode(value)}"
          end
        end.join('&')
      else
        urlencode(params)
      end
    end
      
    def signature(formatted_method, parameters, time, nonce, api_service, hostname, key)
      parameters ||= {}
      input = convert_array_to_hash(parameters.values)
      options = {
        '__method' => formatted_method,
        '__service' => api_service,
        '__hostname' => hostname,
        '__timestamp' => time,
        '__nonce' => nonce
      }
      input.merge!(options)
      raise "Invalid RSA key" unless key =~ /-----BEGIN (RSA )?PRIVATE KEY-----(.*)-----END (RSA )?PRIVATE KEY-----/sim
      serialized_input = encode_params(input)
    
      digest = OpenSSL::Digest::SHA512.new
      private_key = OpenSSL::PKey::RSA.new(key)
      encrypted_asn = private_key.sign(digest, serialized_input)
      readable_encrypted_asn = Base64.encode64(encrypted_asn)
      urlencode(readable_encrypted_asn)
    end    
    
    def to_cookies(content)
      content.map do |item|
        HTTPI::Cookie.new item
      end
    end

    def cookies(method, parameters, username, mode, api_version, api_service, hostname, key)
      time = Time.new.to_i
      #strip out the -'s because transip requires the nonce to be between 6 and 32 chars
      nonce = SecureRandom.uuid.gsub("-", '')
      to_cookies [ "login=#{username}",
                   "mode=#{mode}",
                   "timestamp=#{time}",
                   "nonce=#{nonce}",
                   "clientVersion=#{api_version}",
                   "signature=#{signature(method, parameters, time, nonce, api_service, hostname, key)}"
                 ]
    end

    def fix_array_defs(options)
      options.each_with_object({}) do |(k, v), h|
        h[k] = case v
        when Array
          if v.empty?
            {}
          else
            entry_name = v.first.class.name.split(':').last
            {
              'item' => {:content! => v, :'@xsi:type' => "tns:#{entry_name}"},
              :'@xsi:type' => "tns:ArrayOf#{entry_name}",
              :'@enc:arrayType' => "tns:#{entry_name}[#{v.size}]"
            }
          end
        when Hash
          fix_array_defs(v)
        else
          v
        end
      end
    end

    def request(action, options = {})
      puts "request(#{action}, #{options.inspect})\n"
      formatted_action = camelize(action)

      parameters = {
        :message => fix_array_defs(options),
        :cookies => cookies(formatted_action, options, @username, @mode, API_VERSION, API_SERVICE, ENDPOINT, @key)
      }
      puts "parameters: #{parameters.inspect}\n"
      response = @client.call(action, parameters)

      from_soap(response.body[action][:return])
    end
    
    def from_hash(hash)
      result = {}
      hash.each do |key, value|
        result[key] = from_soap(value) unless key[0].to_s == '@'
      end
      result
    end
    
    def from_soap(input)
      if input.is_a? Array
        result = input.map {|value| from_soap(value)}
      elsif input.is_a? Hash
        if input.keys.first == :item
          result = from_soap(input[:item])
        else
          result = from_hash(input)
        end
      else
        result = input
      end
      result
    end
  end
end
