require 'uri'
require 'openssl'
require 'time'
require 'securerandom'
require 'savon' if Puppet.features.savon?

module Transip
  class Soap
    API_VERSION ||= '5.6'.freeze
    ENDPOINT ||= 'api.transip.nl'.freeze
    API_SERVICE ||= 'DomainService'.freeze
    WSDL ||= "https://#{ENDPOINT}/wsdl/?service=#{API_SERVICE}".freeze
    NAMESPACES ||= { :'xmlns:enc' => 'http://schemas.xmlsoap.org/soap/encoding/' }.freeze

    class << self
      def from_soap(input)
        case input
        when Array
          array_from_soap(input)
        when Hash
          hash_from_soap(input)
        else
          input
        end
      end

      def array_from_soap(input)
        input.map { |value| from_soap(value) }
      end

      def hash_from_soap(hash)
        if hash.keys.include?(:return)
          from_soap(hash[:return])
        elsif hash.keys.include?(:item)
          if hash.keys.include?(:'@soap_enc:array_type') && hash[:'@soap_enc:array_type'].end_with?('[1]')
            from_soap([hash[:item]]) # deal with single element array
          else
            from_soap(hash[:item])
          end
        else
          hash.each_with_object({}) do |(k, v), memo|
            memo[k] = from_soap(v) unless k[0].to_s == '@'
          end
        end
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
          { :item => { :content! => soaped_options, :'@xsi:type' => "tns:#{type}" },
            :'@xsi:type' => "tns:ArrayOf#{type}",
            :'@enc:arrayType' => "tns:#{type}[#{soaped_options.size}]" }
        end
      end

      def hash_to_soap(options)
        options.each_with_object({}) do |(k, v), memo|
          memo[k] = to_soap(v)
        end
      end

      def camelize(word)
        parts = word.to_s.split('_')
        parts.first.downcase + parts[1..-1].map(&:capitalize).join
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
          params.map { |key, value|
            encoded_key = prefix.nil? ? urlencode(key) : "#{prefix}[#{urlencode(key)}]"
            encode(value, encoded_key)
          }.flatten
        when Array
          h = array_to_indexed_hash(params)
          encode(h, prefix)
        else
          ["#{prefix}=#{urlencode(params)}"]
        end
      end

      def message_options(method, api_service, hostname, time, nonce)
        %W[__method=#{camelize(method)} __service=#{api_service} __hostname=#{hostname} __timestamp=#{time} __nonce=#{nonce}]
      end

      def serialize(action, api_service, hostname, time, nonce, options = {})
        (encode(options.values) + message_options(action, api_service, hostname, time, nonce)).join('&')
      end

      def sign(input, private_key)
        digest = OpenSSL::Digest::SHA512.new
        signed_input = private_key.sign(digest, input)
        urlencode(Base64.encode64(signed_input))
      end

      def to_cookie_array(username, mode, time, nonce, api_version, signature)
        %W[login=#{username} mode=#{mode} timestamp=#{time} nonce=#{nonce} clientVersion=#{api_version} signature=#{signature}]
      end

      def cookies(action, username, mode, api_service, api_version, hostname, private_key, options = {})
        time = Time.new.to_i
        # strip out the -'s because transip requires the nonce to be between 6 and 32 chars
        nonce = SecureRandom.uuid.delete('-')
        serialized_input = serialize(action, api_service, hostname, time, nonce, options)
        signature = sign(serialized_input, private_key)
        to_cookie_array(username, mode, time, nonce, api_version, signature).map { |c| HTTPI::Cookie.new(c) }
      end
    end

    def initialize(options = {})
      key = options[:key] || (options[:key_file] && File.read(options[:key_file]))
      raise ArgumentError, 'Invalid RSA key' unless key =~ %r{-----BEGIN (RSA )?PRIVATE KEY-----(.*)-----END (RSA )?PRIVATE KEY-----}sim
      @private_key = OpenSSL::PKey::RSA.new(key)

      @username = options[:username]
      raise ArgumentError, 'The :username and :key options are required' if @username.nil? || key.nil?

      @mode = options[:mode] || :readonly

      @client = Savon::Client.new(wsdl: WSDL, namespaces: NAMESPACES)
    end

    def request(action, options = {})
      response_action = "#{action}_response".to_sym
      message = self.class.to_soap(options)
      cookies = self.class.cookies(action, @username, @mode, API_SERVICE, API_VERSION, ENDPOINT, @private_key, options)
      response = @client.call(action, message: message, cookies: cookies)
      self.class.from_soap(response.body[response_action])
    end
  end
end
