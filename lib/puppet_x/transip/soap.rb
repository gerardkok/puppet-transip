require 'uri'
require 'openssl'
require 'time'
require 'securerandom'
require 'savon' if Puppet.features.savon?

module Transip
  refine Array do
    SOAP_ARRAY_KEYS ||= [:item, :'@soap_enc:array_type', :'@xsi:type'].to_set.freeze

    def to_soap
      if empty?
        {}
      else
        type = first.class.name.split(':').last
        soaped_options = map { |o| o.to_soap }
        { :item => { :content! => soaped_options, :'@xsi:type' => "tns:#{type}" },
          :'@xsi:type' => "tns:ArrayOf#{type}",
          :'@enc:arrayType' => "tns:#{type}[#{soaped_options.size}]" }
      end
    end

    def from_soap
      map { |x| x.from_soap }
    end
  end

  refine Hash do
    def to_soap
      each_with_object({}) do |(k, v), memo|
        memo[k] = v.to_soap
      end
    end

    def single_element_soap_array?
      keys.to_set == SOAP_ARRAY_KEYS && self[:'@soap_enc:array_type'].end_with?('[1]')
    end

    def strip_soap_keys
      if single_element_soap_array?
        { item: [self[:item]] } # turn single element array into proper array
      else
        each_with_object({}) do |(k, v), memo|
          memo[k] = v unless k[0].to_s == '@'
        end
      end
    end

    def from_soap
      h = strip_soap_keys.each_with_object({}) do |(k, v), memo|
        memo[k] = v.from_soap
      end
      (h.keys == [:item] || h.keys == [:return]) ? h[keys.first] : h
    end
  end

  refine Object do
    [:to_soap, :from_soap].each do |m|
      define_method(m) { to_s }
    end
  end

  class Soap
    API_VERSION ||= '5.6'.freeze
    ENDPOINT ||= 'api.transip.nl'.freeze
    API_SERVICE ||= 'DomainService'.freeze
    WSDL ||= "https://#{ENDPOINT}/wsdl/?service=#{API_SERVICE}".freeze
    NAMESPACES ||= { :'xmlns:enc' => 'http://schemas.xmlsoap.org/soap/encoding/' }.freeze

    class << self
      def camelize(word)
        parts = word.to_s.split('_')
        parts.first.downcase + parts[1..-1].map(&:capitalize).join
      end

      def to_indexed_hash(array)
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
          h = to_indexed_hash(params)
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
      raise ArgumentError, 'Invalid RSA key' unless key =~ %r{-----BEGIN (RSA )?PRIVATE KEY-----(.*)-----END (RSA )?PRIVATE KEY-----}sm
      @private_key = OpenSSL::PKey::RSA.new(key)

      @username = options[:username]
      raise ArgumentError, 'The :username and :key options are required' if @username.nil? || key.nil?

      @mode = options[:mode] || :readonly

      @client = Savon::Client.new(wsdl: WSDL, namespaces: NAMESPACES)
    end

    def request(action, options = {})
      response_action = "#{action}_response".to_sym
      message = options.to_soap
      cookies = self.class.cookies(action, @username, @mode, API_SERVICE, API_VERSION, ENDPOINT, @private_key, options)
      response = @client.call(action, message: message, cookies: cookies)
      response.body[response_action].from_soap
    end
  end
end
