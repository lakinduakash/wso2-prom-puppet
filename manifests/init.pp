# Class: prometheus_install
#
#
class prometheus_install {
  # resources
  package { 'ntp':
      ensure => installed,
    }

}
