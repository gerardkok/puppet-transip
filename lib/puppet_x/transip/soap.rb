require 'uri'
require 'openssl'
require 'savon' if Puppet.features.savon?

module Transip
  class Soap
    API_VERSION ||= '5.6'.freeze
    ENDPOINT ||= 'api.transip.nl'.freeze
    API_SERVICE ||= 'DomainService'.freeze
    WSDL ||= "https://#{ENDPOINT}/wsdl/?service=#{API_SERVICE}".freeze

    class << self
       def from_hash(hash)
        firstkey = hash.keys.first
        if firstkey == :item || firstkey == :return
          from_soap(hash[firstkey])
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

      def camelize(word)
        parts = word.to_s.split('_')
        parts.first.downcase + parts[1..-1].map{ |p| p.capitalize }.join
      end
  
      def array_to_indexed_hash(array)
        Hash[(0...array.size).zip(array)]
      end
      
      def urlencode(input)
        URI.encode_www_form_component(input.to_s).gsub('+', '%20').gsub('%7E', '~').gsub('*', '%2A')
      end
  
      def encode(params, prefix = nil)
        case params
        when Hash
          params.map do |key, value|
            encoded_key = prefix.nil? ? urlencode(key) : "#{prefix}[#{urlencode(key)}]"
            encode(value, encoded_key)
          end
        when Array
          h = array_to_indexed_hash(params)
          encode(h, prefix)
        else
          ["#{prefix}=#{urlencode(params)}"]
        end
      end
  
      def message_options(method, api_service, hostname, time, nonce)
        %W[ __method=#{camelize(method)} __service=#{api_version} __hostname=#{hostname} __timestamp=#{time} __nonce=#{nonce} ]
      end
  
      def sign(input, private_key)
        digest = OpenSSL::Digest::SHA512.new
        signed_input = private_key.sign(digest, input)
        urlencode(Base64.encode64(signed_input))
      end
  
      def to_cookie_array(username, mode, time, nonce, api_version, signature)
        %W[ login=#{username} mode=#{mode} timestamp=#{time} nonce=#{nonce} clientVersion=#{api_version} signature=#{signature} ]
      end
  
      def cookies(action, username, mode, api_version, hostname, private_key, options = {})
        time = Time.new.to_i
        #strip out the -'s because transip requires the nonce to be between 6 and 32 chars
        nonce = SecureRandom.uuid.gsub("-", '')
        serialized_input = (encode(options.values) + message_options(action, api_version, hostname, time, nonce)).join('&')
        signature = sign(serialized_input, private_key)
        to_cookie_array(username, mode, time, nonce, api_version, signature).map { |c| HTTPI::Cookie.new(c) }
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
          type = options.first.class.name.split(':').last
          soaped_options = options.map { |o| to_soap(o) }
          { item: { content!: soaped_options, '@xsi:type': "tns:#{type}" },
            '@xsi:type': "tns:ArrayOf#{type}",
            '@enc:arrayType': "tns:#{type}[#{soaped_options.size}]"
          }
        end
      end
  
      def hash_to_soap(options)
        options.each_with_object({}) do |(k, v), memo|
          memo[k] = to_soap(v)
        end
      end
    end

    def initialize(options = {})
      key = options[:key] || (options[:key_file] && File.read(options[:key_file]))
      raise ArgumentError, 'Invalid RSA key' unless key =~ /-----BEGIN (RSA )?PRIVATE KEY-----(.*)-----END (RSA )?PRIVATE KEY-----/sim
      @private_key = OpenSSL::PKey::RSA.new(key)

      @username = options[:username]
      raise ArgumentError, 'The :username and :key options are required' if @username.nil? or key.nil?

      @mode = options[:mode] || :readonly

      @client = Savon::Client.new(wsdl: WSDL) do
        namespaces(
          'xmlns:enc' => 'http://schemas.xmlsoap.org/soap/encoding/'
        )
      end
    end

    def request(action, options = {})
      response_action = "#{action}_response".to_sym
      message = self.to_soap(options)
      cookies = self.cookies(action, @username, @mode, API_VERSION, ENDPOINT, @private_key, options)
      response = @client.call(action, message: message, cookies: cookies)
      self.from_soap(response.body[response_action])
    end
  end
end
