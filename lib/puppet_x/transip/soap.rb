require 'uri'
require 'openssl'
require 'savon' if Puppet.features.savon?

module Transip
  class Soap
    API_VERSION ||= '5.6'.freeze
    ENDPOINT ||= 'api.transip.nl'.freeze
    API_SERVICE ||= 'DomainService'.freeze
    WSDL ||= "https://#{ENDPOINT}/wsdl/?service=#{API_SERVICE}".freeze

    def initialize(options = {})
      @key = options[:key] || (options[:key_file] && File.read(options[:key_file]))
      raise "Invalid RSA key" unless @key =~ /-----BEGIN (RSA )?PRIVATE KEY-----(.*)-----END (RSA )?PRIVATE KEY-----/sim

      @username = options[:username]
      raise ArgumentError, "The :username and :key options are required!" if @username.nil? or @key.nil?

      @mode = options[:mode] || :readonly

      @savon_options = {
        :wsdl => WSDL
      }

      @client = Savon::Client.new(@savon_options) do
        namespaces(
          'xmlns:enc' => 'http://schemas.xmlsoap.org/soap/encoding/'
        )
      end
#      puts "client: #{@client.inspect}\n"
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
      
    def signature(method, parameters = {}, time, nonce)
      input = convert_array_to_hash(parameters.values)
      options = {
        '__method' => method,
        '__service' => API_SERVICE,
        '__hostname' => ENDPOINT,
        '__timestamp' => time,
        '__nonce' => nonce
      }
      serialized_input = encode_params(input.merge(options))
    
      digest = OpenSSL::Digest::SHA512.new
      private_key = OpenSSL::PKey::RSA.new(@key)
      encrypted_asn = private_key.sign(digest, serialized_input)
      readable_encrypted_asn = Base64.encode64(encrypted_asn)
      urlencode(readable_encrypted_asn)
    end    
    
    def to_cookies(content)
      content.map do |item|
        HTTPI::Cookie.new item
      end
    end

    def cookies(method, parameters)
      time = Time.new.to_i
      #strip out the -'s because transip requires the nonce to be between 6 and 32 chars
      nonce = SecureRandom.uuid.gsub("-", '')
      to_cookies [ "login=#{@username}",
                   "mode=#{@mode}",
                   "timestamp=#{time}",
                   "nonce=#{nonce}",
                   "clientVersion=#{API_VERSION}",
                   "signature=#{signature(method, parameters, time, nonce)}"
                 ]
    end

    def to_soap(options)
      case options
      when Array
        array_to_soap(options)
      when Hash
        hash_to_soap(options)
      else
        options
      end
    end
    
    def array_to_soap(options)
      if options.empty?
        {}
      else
        entry_type = options.first.class.name.split(':').last
        soaped_opts = options.map { |o| to_soap(o) }
        {
          'item' => {:content! => soaped_opts, :'@xsi:type' => "tns:#{entry_type}"},
          :'@xsi:type' => "tns:ArrayOf#{entry_type}",
          :'@enc:arrayType' => "tns:#{entry_type}[#{options.size}]"
        }
      end
    end
    
    def hash_to_soap(options)
      options.each_with_object({}) do |(k, v), memo|
        memo[k] = to_soap(v)
      end
    end

    def request(action, options = {})
      puts "request(#{action}, #{options.inspect})\n"
      formatted_action = camelize(action)

      parameters = {
        :message => to_soap(options),
        :cookies => cookies(formatted_action, options)
      }
      puts "parameters: #{parameters.inspect}\n"
      response = @client.call(action, parameters)
      puts "response: #{response}\n"
      puts "response body: #{response.body}\n"
      response_action = "#{action}_response".to_sym
      puts "response action: #{response_action}\n"
      result = from_soap(response.body.values.first[:return])
      puts "result: #{result}\n"
      result

#      r = from_soap(result)
#      puts "return: #{r}\n"
#      r
    end
    
    def from_hash(hash)
      if hash.keys.first == :item
        from_soap(hash[:item])
      else
        hash.each_with_object({}) do |(k, v), memo|
          memo[k] = from_soap(v) unless k[0].to_s == '@'
        end
      end
    end
    
    def from_soap(input)
      if input.is_a? Array
        input.map {|value| from_soap(value)}
      elsif input.is_a? Hash
        from_hash(input)
      else
        input
      end
    end
  end
end
