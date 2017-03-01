class cfssl::install inherits cfssl {

  assert_private("Use of private class ${name} by ${caller_module_name}")

  file { $cfssl::download_dir:
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  if $cfssl::use_proxy == true {
    $cfssl::binaries.each |$key, $value| {
      archive { "${cfssl::download_dir}/${value}":
        ensure       => present,
        source       => "${cfssl::download_url}/${value}",
        path         => "${cfssl::download_dir}/${value}",
        creates      => "${cfssl::download_dir}/${value}",
        user         => 'root',
        group        => 'root',
        cleanup      => false,
        proxy_server => $cfssl::proxy_server,
        proxy_type   => $cfssl::proxy_type,
        require      => File[ $cfssl::download_dir ],
      }
      ->
      file { "${cfssl::download_dir}/${value}":
        mode => '0755',
      }
      ->
      file { "${cfssl::install_dir}/${key}":
        ensure => link,
        owner  => 'root',
        group  => 'root',
        target => "${cfssl::download_dir}/${value}",
      }
    }
  } else {
    $cfssl::binaries.each |$key, $value| {
      archive { "${cfssl::download_dir}/${value}":
        ensure  => present,
        source  => "${cfssl::download_url}/${value}",
        path    => "${cfssl::download_dir}/${value}",
        creates => "${cfssl::download_dir}/${value}",
        user    => 'root',
        group   => 'root',
        cleanup => false,
        require => File[ $cfssl::download_dir ],
      }
      ->
      file { "${cfssl::download_dir}/${value}":
        mode => '0755',
      }
      ->
      file { "${cfssl::install_dir}/${key}":
        ensure => link,
        owner  => 'root',
        group  => 'root',
        target => "${cfssl::download_dir}/${value}",
      }
    }
  }
}
