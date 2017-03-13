require 'json'
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
    certfile = File.join(config_path, "#{resource[:cn]}.pem")
    return nil if !File.exist?(certfile)
  end

  def exists?
    file_check != nil
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
