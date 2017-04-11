require 'puppet/util'

Puppet::Type.newtype(:cfssl_cert) do
  desc 'Manage cfssl generated private keys'

  ensurable

  newparam(:name, :namevar => true) do
    desc 'namevar, cert file fully qualified file path'
    validate do |value|
      unless Puppet::Util.absolute_path? value
        raise ArgumentError, "cert file path must be absolute: #{value}"
      end
    end
  end

  newparam(:cn) do
    desc 'Certificate Common Name'
  end

  newparam(:hosts, :array_matching => :all) do
    desc "List of alternate hostnames for the certificate"
    munge do |value|
      if value.is_a? String
        Array(value)
      else
        value
      end
    end
  end

  newparam(:key_algo) do
    desc 'Cert algorithm'
    newvalues(:ecdsa, :rsa)
    defaultto :rsa
  end

  newparam(:key_size) do
    desc 'Size of key'
    munge do |value|
      Integer(value)
    end
  end

  newparam(:country) do
    desc 'Country'
    munge do |value|
      value[0,2].upcase
    end
  end

  newparam(:state) do
    desc 'State'
    munge do |value|
      value[0,2].upcase
    end
  end

  newparam(:locality) do
    desc 'Locality'
  end

  newparam(:organization) do
    desc 'Organization'
  end

  newparam(:ou) do
    desc 'Organizational Unit'
  end

  newparam(:remote) do
    desc 'remote CFSSL server'
  end

  newparam(:authsign) do
    desc 'Should we hit the authsign endpoint'
    defaultto :false
  end

  newparam(:authkey) do
    desc 'The auth key to use when contacting the CA'
  end

  newparam(:profile) do
    desc 'The profile to use when contacting the CA'
    defaultto :server
  end

end
