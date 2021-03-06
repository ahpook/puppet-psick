# This class installs git using tp
#
# @param ensure Define if to install or remove git
#
class psick::git (
  Enum['present','absent'] $ensure = 'present',
) {
  tp::install { 'git':
    ensure => $ensure,
  }
}
