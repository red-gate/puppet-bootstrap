# puppet-bootstrap
Collection of scripts for bootstrapping puppet agent on various Linux machines

## Ubuntu

Tested mostly on Ubuntu 16.04 LTS.

## Raspberry Pi

Tested on Puppet 5.5.0 on Raspbian as supplied by NOOBS 2.7.0 (retrieved 2018-04-05), running on a Pi 3.

Note that the apt-supplied version of `bundler` (1.13) is too old to know about recent Ruby versions, so even though you don't actually need them, the mention of architecture `mri_25` in `Gemfile` is sufficient to confuse it. If it complains about this, check that `bundle --version` reports >= 1.16.1.  