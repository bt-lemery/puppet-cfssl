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

  def comp
    File.basename("#{resource[:name]}")
  end

  def extn
    File.extname("#{resource[:name]}")
  end

  def bare_name
    File.basename "#{resource[:name]}", extn
  end

  def key_check
    keyfile = config_path.to_s + "/" +bare_name.to_s + "-key" +extn.to_s
    if !(File.exist?(keyfile))
      return false
    else
      key = OpenSSL::PKey.read(File.read(keyfile))
      unless resource[:key_size].to_i == key.n.num_bits
        return false
      end
      if (key.class.to_s != "OpenSSL::PKey::RSA") && (resource[:key_algo].to_s == "rsa")
        return false
      end
      if (key.class.to_s == "OpenSSL::PKey::EC") && (resource[:key_algo].to_s == "ecdsa")
        return false
      end
      return true
    end
  end

  def cert_check
    certfile = "#{resource[:name]}"
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
    payload = { "CN" => resource[:cn], "key" => { "algo" => resource[:key_algo], "size" => resource[:key_size] }, "hosts" => resource[:hosts], "names" => [ { "C" => resource[:country], "ST" => resource[:state], "L" => resource[:locality], "O" => resource[:organization], "OU" => resource[:ou] } ] }

    json_response = request(resource[:remote], api_root, "newkey", payload)

    pkey = json_response["result"]["private_key"].to_s
    csr = json_response["result"]["certificate_request"].to_s

    keyfile = config_path.to_s + "/" +bare_name.to_s + "-key" +extn.to_s
    f = File.open("#{keyfile}", "w")
    f.write(pkey)
    f.close

    csrfile = config_path.to_s + "/" +bare_name.to_s + ".csr"
    f = File.open("#{csrfile}", "w")
    f.write(csr)
    f.close

    if resource[:authsign] == true
      key = resource[:authkey].to_s

      hexkey = [ key ].pack 'H*'

      instance = OpenSSL::HMAC.new(hexkey, OpenSSL::Digest.new('sha256'))
      csr = File.open("#{csrfile}").read
      intermediate_payload = { "certificate_request" => "#{csr}", "profile" => "#{resource[:profile]}" }.to_json
      instance.update(intermediate_payload)
      token = Base64.encode64(instance.digest).chomp!

      encoded_intermediate_payload = Base64.encode64(intermediate_payload)
      request = encoded_intermediate_payload.gsub(/\n/, "")

      payload = { "token" => "#{token}", "request" => "#{request}" }

      json_response = request(resource[:remote], api_root, "authsign", payload)

    else
      payload = { "certificate_request" => "#{csr}", "profile" => "#{resource[:profile]}" }

      json_response = request(resource[:remote], api_root, "sign", payload)
    end

    cert = json_response["result"]["certificate"].to_s

    certfile = "#{resource[:name]}"
    f = File.open("#{certfile}", "w")
    f.write(cert)
    f.close

    @property_hash[:ensure] = :present
  end

end
