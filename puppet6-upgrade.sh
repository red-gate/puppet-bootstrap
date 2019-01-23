#!/bin/bash

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "Usage: sudo puppet6-rpi-bootstrap.sh" 1>&2
   exit 1
fi

# Check we already have a csr_attributes.yaml present - if not, prompt to create
if [ ! -f /etc/puppetlabs/puppet/csr_attributes.yaml ]; then
	echo "No csr_attributes.yaml found. Enter extended certificate attributes:"
	read -p "pp_environment: " PP_ENVIRONMENT
	read -p "pp_service: " PP_SERVICE
	read -p "pp_role: " PP_ROLE

	echo "extension_requests:" >> /etc/puppetlabs/puppet/csr_attributes.yaml
	[ $PP_ENVIRONMENT ] && echo "    pp_environment: $PP_ENVIRONMENT" >> /etc/puppetlabs/puppet/csr_attributes.yaml
	[ $PP_SERVICE ] && echo "    pp_service: $PP_SERVICE" >> /etc/puppetlabs/puppet/csr_attributes.yaml
	[ $PP_ROLE ] && echo "    pp_role: $PP_ROLE" >> /etc/puppetlabs/puppet/csr_attributes.yaml
fi

# Stop the old puppet agent and clean up its SSL directory
sudo service puppet stop
sudo rm -rf /etc/puppetlabs/puppet/ssl

# Remove any old release packages
sudo dpkg -r puppet5-release
sudo dpkg -r puppet4-release

# If we were previously pointing at our Puppet 4 master, move over to Puppet 6
OLDPORT=`sudo /opt/puppetlabs/puppet/bin/puppet config print --section main masterport`
if [ "$OLDPORT" == "8141" ]; then
	sudo /opt/puppetlabs/puppet/bin/puppet config set --section main masterport 8142
fi

# Point at the new Puppet 6 server
sudo /opt/puppetlabs/puppet/bin/puppet config set --section main server puppet6.red-gate.com

# Install the new agent
wget https://apt.puppetlabs.com/puppet6-release-`lsb_release -c -s`.deb && sudo dpkg -i puppet6-release-`lsb_release -c -s`.deb
sudo apt update && sudo apt install puppet-agent

# And first run...
sudo /opt/puppetlabs/bin/puppet agent -t
