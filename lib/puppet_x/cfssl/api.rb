require 'json'
require 'net/http'
require 'puppet'
require 'uri'

module Cfssl
  # documentation goes here
  class Api < Puppet::Provider

    def self.request(remote_ca, cn, api_root, action, payload = nil, path)
      begin
        Puppet.debug "After begin"
        uri = URI.parse("#{remote_ca}/#{api_root}/#{action}")
        response = Net::HTTP.start(uri.host, uri.port) do |http|
          request = Net::HTTP::Post.new(uri.request_uri, 'Content-Type' => 'application/json')
          request.body = payload.to_json
          Puppet.debug "Sending #{request.method} request to #{uri}"
          http.request(request)
      end

      unless response.code =~ /^2/
        raise Puppet::Error, "[ERROR]: #{method} Request to #{uri} failed: #{response.code} #{response.message}"
      end

      json_response = JSON.parse(response.body)

      json_response

      rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError,
           Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => e
        raise Puppet::Error, "[ERROR] Encountered error while contacting CFSSL endpoint: #{e}"
      end
    end

    def request(*args)
      self.class.request(*args)
    end

  end
end
