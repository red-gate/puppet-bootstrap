#!/bin/bash

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "Usage: sudo puppet6-rpi-bootstrap.sh" 1>&2
   exit 1
fi

# Make sure we have a sensible hostname
if [ -z "$NEWHOSTNAME" ]; then
    read -p "Enter a hostname for this machine: " NEWHOSTNAME
fi
echo "Using new hostname from NEWHOSTNAME: $NEWHOSTNAME"
hostname $NEWHOSTNAME
echo $NEWHOSTNAME > /etc/hostname

if [ -z "$PUPPETMASTER" ]; then
    read -p "Enter puppet server hostname: " PUPPETMASTER
fi
echo "Using puppet server: $PUPPETMASTER"

if [ -z "$MASTERPORT" ]; then
    read -p "Enter puppet server port (8140 is the normal one): " MASTERPORT
fi
echo "Using server port: $MASTERPORT"

if [ -z "$PUPPETENV" ]; then
    read -p "Enter Puppet environment name (e.g. production): " PUPPETENV
fi
echo "Using Puppet environment: $PUPPETENV"

if [ -z "$PP_ENVIRONMENT$PP_SERVICE$PP_ROLE" ]; then
    read -p "Set extra certificate attributes? [y/N]:" SET_EXTRA_ATTRIBUTES
    if [ $SET_EXTRA_ATTRIBUTES ] && [ ${SET_EXTRA_ATTRIBUTES,,} == "y" ]; then
    	read -p "pp_environment: " PP_ENVIRONMENT
    	read -p "pp_service: " PP_SERVICE
    	read -p "pp_role: " PP_ROLE
    fi
fi
echo "Extended certificate attributes:"
echo "  pp_environment: $PP_ENVIRONMENT"
echo "  pp_service: $PP_SERVICE"
echo "  pp_role: $PP_ROLE"

echo "Thanks. Beginning set up. This compiles from source so will likely take a long time..."
# add puppet repo
mkdir setup-temp
cd setup-temp

apt-get update || exit 1
apt-get install ruby-full facter hiera unzip build-essential -y || exit 1
gem install bundler
gem install semantic_puppet

wget https://github.com/puppetlabs/puppet/archive/6.2.0.tar.gz || exit 1
tar xzf 6.2.0.tar.gz || exit 1
cd puppet-6.2.0

bundle install --path .bundle/gems || exit 1
bundle update || exit 1
ruby install.rb || exit 1

# Note: we used to add /opt/puppetlabs/bin to the path here, but it would seem Puppet 5.5 at least puts it in /usr/bin/puppet anyway, so no need...

puppet config set server $MASTER --section main || exit 1

puppet config set masterport $MASTERPORT --section main

puppet config set environment $PUPPETENV --section agent || exit 1

# If we're setting extra cert attributes, do that now
if [ ! -z "$PP_ENVIRONMENT$PP_SERVICE$PP_ROLE" ]; then
	echo "extension_requests:" >> /etc/puppetlabs/puppet/csr_attributes.yaml
	[ $PP_ENVIRONMENT ] && echo "    pp_environment: $PP_ENVIRONMENT" >> /etc/puppetlabs/puppet/csr_attributes.yaml
	[ $PP_SERVICE ] && echo "    pp_service: $PP_SERVICE" >> /etc/puppetlabs/puppet/csr_attributes.yaml
	[ $PP_ROLE ] && echo "    pp_role: $PP_ROLE" >> /etc/puppetlabs/puppet/csr_attributes.yaml
fi

# These modules are normally baked into the agent install, but since we aren't using the
# official packages on ARM, install them manually...
# https://github.com/puppetlabs/puppet-specifications/blob/master/moving_modules.md
puppet module install puppetlabs-augeas_core --target-dir /opt/puppetlabs/puppet/vendor_modules/
puppet module install puppetlabs-cron_core --target-dir /opt/puppetlabs/puppet/vendor_modules/
puppet module install puppetlabs-host_core --target-dir /opt/puppetlabs/puppet/vendor_modules/
puppet module install puppetlabs-k5login_core --target-dir /opt/puppetlabs/puppet/vendor_modules/
puppet module install puppetlabs-mailalias_core --target-dir /opt/puppetlabs/puppet/vendor_modules/
puppet module install puppetlabs-maillist_core --target-dir /opt/puppetlabs/puppet/vendor_modules/
puppet module install puppetlabs-mount_core --target-dir /opt/puppetlabs/puppet/vendor_modules/
puppet module install puppetlabs-nagios_core --target-dir /opt/puppetlabs/puppet/vendor_modules/
puppet module install puppetlabs-selinux_core --target-dir /opt/puppetlabs/puppet/vendor_modules/
puppet module install puppetlabs-sshkeys_core --target-dir /opt/puppetlabs/puppet/vendor_modules/
puppet module install puppetlabs-yumrepo_core --target-dir /opt/puppetlabs/puppet/vendor_modules/
puppet module install puppetlabs-zfs_core --target-dir /opt/puppetlabs/puppet/vendor_modules/
puppet module install puppetlabs-zone_core --target-dir /opt/puppetlabs/puppet/vendor_modules/

puppet agent -t

echo 'Sign this node on the server and press [enter] here when done...'
read dummy

# Enable puppet
puppet agent --enable

# Run it for reals
puppet agent -t

# Enable the service
puppet resource service puppet ensure=running enable=true
