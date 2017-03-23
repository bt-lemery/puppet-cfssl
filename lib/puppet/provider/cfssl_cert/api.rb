require 'json'
require 'openssl'
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
    '/etc/cfssl'
  end

  def file_check
    keyfile  = File.join(config_path, "#{resource[:cn]}-key.pem")
    certfile = File.join(config_path, "#{resource[:cn]}.pem")
    unless (File.exist?(certfile)) && (File.exist?(keyfile))
      return false
    end
    return true
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

  def exists?
    #file_check
    cert_check
    key_check
  end

  def create
    payload = { "CN" => resource[:cn], "key" => { "algo" => resource[:algo], "size" => resource[:key_size] }, "hosts" => resource[:hosts], "names" => [ { "C" => resource[:country], "ST" => resource[:state], "L" => resource[:locality], "O" => resource[:organization], "OU" => resource[:ou] } ] }

    json_response = request(resource[:remote], resource[:cn], api_root, "newkey", payload, config_path)

    pkey = json_response["result"]["private_key"].to_s
    csr = json_response["result"]["certificate_request"].to_s

    f = File.open("#{config_path}/#{resource[:cn]}-key.pem", "w")
    f.write(pkey)
    f.close

    f = File.open("#{config_path}/#{resource[:cn]}.csr", "w")
    f.write(csr)
    f.close

    payload = { "certificate_request" => "#{csr}", "profile" => "ca" }

    json_response = request(resource[:remote], resource[:cn], api_root, "sign", payload, config_path)

    cert = json_response["result"]["certificate"].to_s

    f = File.open("#{config_path}/#{resource[:cn]}.pem", "w")
    f.write(cert)
    f.close

    @property_hash[:ensure] = :present
  end

end
