require 'json'
require 'openssl'
require 'base64'
require_relative '../../../puppet_x/cfssl/api.rb'

Puppet::Type.type(:cfssl_cert).provide(:api, :parent => Cfssl::Api) do
  mk_resource_methods

  def request(*args)
    self.class.request(*args)
  end

  def self.api_root
    'api/v1/cfssl'
  end

  def api_root
    self.class.api_root
  end

  def config_path
    File.dirname("#{resource[:name]}")
  end

  def authsign
    false
  end

  def key_check
    keyfile = File.join(config_path, "#{resource[:cn]}-key.pem")
    if !(File.exist?(keyfile))
      return false
    else
      key = OpenSSL::PKey.read(File.read(keyfile))
      unless resource[:key_size].to_i == key.n.num_bits
        return false
      end
      if (key.class.to_s != "OpenSSL::PKey::RSA") && (resource[:algo].to_s == "rsa")
        return false
      end
      if (key.class.to_s == "OpenSSL::PKey::EC") && (resource[:algo].to_s == "ecdsa")
        return false
      end
      return true
    end
  end

  def cert_check
    certfile = File.join(config_path, "#{resource[:cn]}.pem")
    if !(File.exist?(certfile))
      return false
    else
      cert = OpenSSL::X509::Certificate.new(File.read(certfile))
      subject = cert.subject.to_a.inject({}) { |k,v| k.merge!({v[0] => v[1]})}
      if ("#{resource[:country]}" != "#{subject["C"]}") ||
        ("#{resource[:state]}" != "#{subject["ST"]}") ||
        ("#{resource[:locality]}" != "#{subject["L"]}") ||
        ("#{resource[:organization]}" != "#{subject["O"]}") ||
        ("#{resource[:ou]}" != "#{subject["OU"]}") ||
        ("#{resource[:cn]}" != "#{subject["CN"]}")
        return false
      else
        return true
      end
    end
  end

  def exists?
    key_check
    cert_check
  end

  def create
    payload = { "CN" => resource[:cn], "key" => { "algo" => resource[:algo], "size" => resource[:key_size] }, "hosts" => resource[:hosts], "names" => [ { "C" => resource[:country], "ST" => resource[:state], "L" => resource[:locality], "O" => resource[:organization], "OU" => resource[:ou] } ] }

    json_response = request(resource[:remote], api_root, "newkey", payload)

    pkey = json_response["result"]["private_key"].to_s
    csr = json_response["result"]["certificate_request"].to_s

    f = File.open("#{config_path}/#{resource[:cn]}-key.pem", "w")
    f.write(pkey)
    f.close

    f = File.open("#{config_path}/#{resource[:cn]}.csr", "w")
    f.write(csr)
    f.close

    if authsign == true
      key = File.open("#{config_path}/auth.key").read.chomp!

      hexkey = [ key ].pack 'H*'

      instance = OpenSSL::HMAC.new(hexkey, OpenSSL::Digest.new('sha256'))
      csr = File.open("#{config_path}/#{resource[:cn]}.csr").read
      intermediate_payload = { "certificate_request" => "#{csr}", "profile" => "server" }.to_json
      instance.update(intermediate_payload)
      token = Base64.encode64(instance.digest).chomp!

      encoded_intermediate_payload = Base64.encode64(intermediate_payload)
      request = encoded_intermediate_payload.gsub(/\n/, "")

      payload = { "token" => "#{token}", "request" => "#{request}" }

      json_response = request(resource[:remote], api_root, "authsign", payload)

    else
      payload = { "certificate_request" => "#{csr}", "profile" => "server" }

      json_response = request(resource[:remote], api_root, "sign", payload)
    end

    cert = json_response["result"]["certificate"].to_s

    f = File.open("#{config_path}/#{resource[:cn]}.pem", "w")
    f.write(cert)
    f.close

    @property_hash[:ensure] = :present
  end

end
