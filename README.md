# PSICK: The Infrastructure Puppet module

[![Build Status](https://travis-ci.org/example42/puppet-psick.png?branch=master)](https://travis-ci.org/example42/puppet-psick)
[![Codacy Badge](https://api.codacy.com/project/badge/Grade/503831d4ea6a470e864f1a3969449b78)](https://www.codacy.com/app/example42/puppet-psick?utm_source=github.com&amp;utm_medium=referral&amp;utm_content=example42/puppet-psick&amp;utm_campaign=Badge_Grade)

This is the PSICK (Puppet Systems Infrastructure Construction Kit) module.
 
It is what we call an **Infrastructure** Puppet **module**. It provides:

  - Solid management of **classification**. Entirely hiera driven.
  - An integrated set of **profiles** for common systems management activities
  - A growing number flexible set of **tp profiles** for applications
  - Integrated and automated firewall (WIP) and monitoring management
  - Safe and easy to be integrated in existing setups, cohexists with other modules, allows expandibility by design.
  - Entirely Hiera driven: In practice a DSL to configure infrastructures
 
It can be used together with the [PSICK control-repo](https://github.com/example42/psick) (check the [Hiera data](https://github.com/example42/psick/tree/production/hieradata) there for sample usage patterns) or as a strandalone module, just:

    include psick

This doesn't do anything at all, by default, but is enough to let you manage *everything* via Hiera.

In the following examples we will use Hiera YAML files, but any backend can be used: psick is a normal, even if somehow unusual, Puppet module, with classes (a lot of them) whose params can be set as Hiera data, defines, templates, files, fuctions, custom data types etc.


## Do You Speak Psick?

Psick "language" has the syntax of any Hiera supported backend (here we use YAML), and the semantic you are going to discover here.

The module provides 3 major features:

  - Structured cross-os, staged **classification** 
  - Base **profiles** for common system configurations
  - Standardised and multifunctional **tp profiles** for applications

### Classification

Psick can manage the whole classification of the nodes of an infrastructure. It can work side by side and External Node Classifier, or it can totally replace it.

All you need is to include the psick class and define, using ```${::kernel}_class``` parameters, which classes to include in a node in different phases.

Psick provides 4 phases, managed by the relevant subclasses:

  - **firstrun**, optional phase, in which the resulting catalog is applied only once, at the first Puppet run. After a reboot can optionally be triggered and the real definitive catalog is applied.
  - **pre**, prerequisites classes, they are applied in a normal catalog run (that is, always except in the very first Puppet run, if firstrun is enabled) before all the other classes.
  - **base**, base classes, common to all the nodes (but exceptions can be applied), applied in normal catalog runs after the pre classes and before the profiles.
  - **profiles**, exactly as in the roles and profiles pattern. The profile classes that differentiate nodes by their role or function. Profiles are applied after the base classes are managed.

An example of configurations, both for Linux and Windows nodes that use all the above phases:

    # First run mode must be enabled and each class to include there explicitely defined:
    psick::enable_firstrun: true
    psick::firstrun::linux_classes:
      hostname: psick::hostname
      packages: psick::aws::sdk
    psick::firstrun::windows_classes:
      hostname: psick::hostname
      packages: psick::aws::sdk

    # Pre and base classes, both on Linux and Windows
    psick::pre::linux_classes:
      puppet: ::puppet
      dns: psick::dns::resolver
      hostname: psick::hostname
      hosts: psick::hosts::resource
      repo: psick::repo
    psick::base::linux_classes:
      sudo: psick::sudo
      time: psick::time
      sysctl: psick::sysctl
      update: psick::update
      ssh: psick::openssh::tp
      mail: psick::postfix::tp
      mail: psick::users::ad

    psick::pre::windows_classes:
      hosts: psick::hosts::resource
    psick::base::windows_classes:
      features: psick::windows::features
      registry: psick::windows::registry
      services: psick::windows::services
      time: psick::time
      users: psick::users::ad

    # Profiles for specific roles (ie: webserver)
    psick::profiles::linux_classes:
      webserver: apache
    psick::profiles::windows_classes:
      webserver: iis

The each key-pair of these $kernel_classes parameters contain an arbitrary tag or marker (users, time, services, but could be any string), and the name the class to include.

This name must be a valid class, which can be found in the Puppet Master modulepath (so probably defined in your control-repo ```Puppetfile```): you can use any of the predefinied Psick profiles, or your own local site profiles, or directly classes from public modules and configure them via Hiera in their own namespace.

To manage exceptions and use a different class on different nodes is enough to specify the alternative class name as value for the used marker (here 'ssh'), in the appropriate Hiera file: 

    psick::base::linux_classes:
      ssh: ::profile::ssh_bastion

To completely disable on specific nodes the usage of a class, included in a general hierarhy level, set the class name to an empty string:

    psick::base::linux_classes:
      ssh: ''

This is the classification part, since it's based on class parameters, it can be managed with flexibility via Hiera and can cohexist (even if this might not be an optimal choice) with other classifications methods.

The pre -> base -> profiles order is strictly enforced, so we sure to place your class in the most appropriate phase (even if functionally they all do the same work: include the specified classes) and, to prevent dependency cycles, avoid to set the same class in two different phases.


#### Auto configuration defaults

If you are lazy or want to try some predefined defaults (always WIP) you can simply try to use one of our embedded sets of configurations, note that you can customise and override everything, in your control-repo hiera data.

For example, to use Psick predefined defaults (as in  ```data/default/*.yaml```):

    psick::auto_conf: default

To use, instead, some hardened defaults (as in ```data/hardened/*.yaml```):

    psick::auto_conf: hardened

The auto configuration settings are defined at module level hierarchy, so they can be overwritten in the environment's Hiera data.


### Psick tp profiles

Psick provides out of the box profiles, based on ([Tiny Puppet](https://github.com/example42/puppet-tp), to manage common applications. They can replace or complement component modules when applications can be managed via packeages, services and files.

They have generated from a common [template](https://github.com/example42/pdk-module-template-tp-profile) so have standard parameters, and are always called ```psick::$app::tp```.

For example to configure Openssh both client and server settings we can write something like:

    # By including the psick::openssh::tp profile we install Openssh via tp
    psick::base::linux_classes:
      ssh: 'psick::openssh::tp'

    # To customise the configuration files to manage at their options:
    psick::openssh::tp::resources_hash:
      tp::conf:
        openssh: # The openssh main configuration file
          template: 'profile/openssh/sshd_config.erb'
        openssh::ssh_config # The /etc/ssh/ssh_config file
          epp: 'profile/openssh/ssh_config.epp'

    # To manage the variables referenced in the used templates (the have to map the same keys):
    psick::openssh::options_hash:
      AllowAgentForwarding: yes
      AllowTcpForwarding: yes
      ListenAddress:
        - 127.0.0.1
        - 0.0.0.0
      PasswordAuthentication: yes
      PermitEmptyPasswords: no
      PermitRootLogin: no

Similary we could manage postfix with data like:

    psick::base::linux_classes:
      mail: 'psick::postfix::tp'

    # To customise the configuration files to manage at their options:
    psick::postfix::tp::resources_hash:
      tp::conf:
        postfix: # Postfix's main.cf
          template: 'profile/postfix/main.cf.erb'
        postfix::master.cf # master.cf
          epp: 'profile/postfix/master.cf.erb'


### Psick base profiles

Basides tp profiles, Psick features a large set of profiles for common baseline configurations.

Some of them are intended to be used both on Linux and Windows, others are more specific.

Here follows a list (incomplete):

### psick::proxy - Proxy Management

If your servers need a proxy to access the Internet you can include the ```psick::proxy``` class directly in your base classes:

    psick::base::linux_classes:
      proxy: '::psick::proxy'

and manage proxy settings with:

    psick::servers:
      proxy:
        host: proxy.example.com
        port: 3128
        user: john    # Optional
        password: xxx # Optional
        no_proxy:
          - localhost
          - "%{::domain}"
          - "%{::fqdn}"
        scheme: http

You can customise the components for which proxy should be configured, here are the default params:

    psick::proxy::ensure: present
    psick::proxy::configure_gem: true
    psick::proxy::configure_puppet_gem: true
    psick::proxy::configure_pip: true
    psick::proxy::configure_system: true
    psick::proxy::configure_repo: true


### psick::hosts::file - /etc/hosts management

This class manages /etc/hosts

To customise its behaviour you can set the template to use to manage ```/etc/hosts```, and the ipaddress, domain and hostname values for the local node (by default the relevant facts values are used):

    psick::hosts::file::template: 'psick/hosts/file/hosts.erb' # Default value
    psick::hosts::file::ipaddress: '10.0.0.4' # Default: $::ipaddress
    psick::hosts::file::domain: 'domain.com' # Default: $::domain
    psick::hosts::file::hostname: 'www01' # Default: $::hostname


### psick::update - Manage packages updates

This class manages how and when a system should be updated, it can be included with the parameter:

    psick::base::linux_classes:
      'update': '::psick::update'

The class just creates a cronjob which runs the system's specific update command. By default the cron schedule is empy so not update is automatically done:

    psick::update::cron_schedule: '0 6 * * *' 

The above setting would create a cron job, executed every day at 6:00 AM, that updates the system's packages.


### psick::sudo - Manage sudo

This class manages sudo. It can be included by setting:

    psick::base::linux_classes:
      'sudo': '::psick::sudo'

You can configure the template to use for ```/etc/sudoers```, the admins who can sudo on your system (if it's used the default or a compatible template), the Puppet fileserver source for the whole content of the ```/etc/sudoers.d/```:

    psick::sudo::sudoers_template: 'psick/sudo/sudoers.erb' # Default value
    psick::sudo::admins: # Default is [] 
      - al
      - mark
      - bill
    psick::sudo::sudoers_d_source: 'puppet:///modules/site/sudo/sudoers.d' # Default is empty

It's also possible to provide an hash of custom sudo directives to pass to the ```::psick::sudo::directive``` define:

    psick::sudo::directives:
      oracle:
        template: 'psick/sudo/oracle.erb'
        order: 30
       
The ```::psick::sudo::directive``` define accepts these params (template, content and source are ALTERNATIVE way to manage the content of the sudo file):

    define psick::sudo::directive (
      Enum['present','absent'] $ensure   = present,
      Variant[Undef,String]    $content  = undef,
      Variant[Undef,String]    $template = undef,
      Variant[Undef,String]    $source   = undef,
      Integer                  $order    = 20,
    ) { ...}


### psick::sysctl - Manage sysctl settings

This class manages sysctl settings. To include it:

    psick::base::linux_classes:
      'sysctl': '::psick::sysctl'

Any sysctl setting can be set via Hiera, using the ```psick::sysctl::settings``` key, which expects an hash like:

    psick::sysctl::settings:
      kernel.shmmni: value: 4096
      kernel.sem: value: 250 32000 100 128

It's possible to specify which sysctl module to use, other than psick internal's default:

    psick::sysctl::module: 'duritong'

The specified module must be on your control-repo's Puppetfile. Not all modules are supported (it's easy to add new ones).


### psick::motd - Manage /etc/motd and /etc/issue files

This class just manages the content of the ```/etc/motd.conf``` and ```/etc/issue``` files. To include it:

    profile::base::linux::motd_class: '::psick::motd'

To customise the content of the provided files:

    psick::motd::motd_file_template: 'psick/motd/motd.erb' # Default value
    psick::motd::issue_file_template: 'psick/motd/issue.erb' # Default value

To avoid to manage these files:

    psick::motd::motd_file_template: ''
    psick::motd::issue_file_template: ''

To remove these files:

    psick::motd::motd_file_ensure: 'absent'
    psick::motd::issue_file_ensure: 'absent'



### psick::oracle - Manage Oracle prerequisites and installation

This psick should be added to oracle servers. By default it does nothing, but, activating the relevant parameters, it allows
the configuration of all the prerequisites for Oracle 12 installation and, if installation files are available, it can automate the installation of Oracle products (via the biemond/oradb external module).

Main use case is the configuration for prerequisites. This can be done with:

    psick::profiles::linux_classes:
      'oracle': psick::oracle

    # Activate the prerequisites class that manages /etc/limits
    psick::oracle::prerequisites::limits_class: 'psick::oracle::prerequisites::limits'

    # Activate the prerequisites class that manages packages
    psick::oracle::prerequisites::packages_class: 'psick::oracle::prerequisites::packages'


    # Activate the prerequisites class that manages users
    psick::oracle::prerequisites::users_class: 'psick::oracle::prerequisites::users'
    psick::oracle::prerequisites::users::has_asm: true # Set this on servers with asm

    # Activate the prerequisites class that manages sysctl
    psick::oracle::prerequisites::sysctl_class: 'psick::oracle::prerequisites::sysctl'
    psick::base::linux_classes:
      'sysctl': '::psick::sysctl' # The base default sysctl class conflicts with the above

    # Activate the prerequisites class that cretaes a swap file (needs petems/swap_file module)
    # psick::oracle::prerequisites::swap_class: 'psick::oracle::prerequisites::swap'

    # Activate the dirs class and create a set of dirs for Oracle data
    psick::oracle::prerequisites::dirs_class: 'psick::oracle::prerequisites::dirs'
    psick::oracle::prerequisites::dirs::base_dir: '/data/oracle' # Default value
    psick::oracle::prerequisites::dirs::owner: 'oracle'          # Default value
    psick::oracle::prerequisites::dirs::group: 'dba'             # Default value
    psick::oracle::prerequisites::dirs::dirs:
     app1:
       - 'db1'
       - 'db2'
     app2:
       - 'db1'
   psick::oracle::prerequisites::dirs::suffixes:   # Default value is ''
     - '_DATA'
     - '_FRA'

with the above settings the following directories are created:

    /data/oracle/app1_DATA/db1
    /data/oracle/app1_DATA/db2
    /data/oracle/app1_FRA/db1
    /data/oracle/app1_FRA/db2
    /data/oracle/app2_DATA/db1
    /data/oracle/app2_FRA/db1


