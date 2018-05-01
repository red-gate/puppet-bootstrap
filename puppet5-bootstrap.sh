#!/bin/bash

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "Usage: sudo puppet5-bootstrap.sh" 1>&2
   # exit 1
fi

# Make sure we have a sensible hostname
read -p "Enter a hostname for this machine: " NEWHOSTNAME
hostname $NEWHOSTNAME
echo $NEWHOSTNAME > /etc/hostname

read -p "Enter puppet master hostname: " PUPPETMASTER

read -p "Enter puppet master port (8140 is the normal one): " MASTERPORT

read -p "Enter Puppet environment name: " PUPPETENV

read -p "Set extra certificate attributes? [y/N]:" SET_EXTRA_ATTRIBUTES
if [ $SET_EXTRA_ATTRIBUTES ] && [ ${SET_EXTRA_ATTRIBUTES,,} == "y" ]; then
	read -p "pp_environment: " PP_ENVIRONMENT
	read -p "pp_service: " PP_SERVICE
	read -p "pp_role: " PP_ROLE
fi

# Download and install puppet
mkdir setup-temp
cd setup-temp

dist=`awk -F= '/^NAME/{print $2}' /etc/os-release`

if [ "$dist" == "\"CentOS Linux\"" ]; then
    version=`awk -F= '/^VERSION_ID/{print $2}' /etc/os-release`
    yum install wget -y || exit 1
    wget https://yum.puppetlabs.com/puppet5/puppet5-release-el-${version//\"}.noarch.rpm || exit 1
    rpm -Uvh puppet5-release-el-${version//\"}.noarch.rpm || exit 1
    yum update || exit 1
    yum install puppet-agent -y || exit 1
elif [ "$dist" == "\"Ubuntu\"" ]; then
    wget https://apt.puppetlabs.com/puppet5-release-`lsb_release -c -s`.deb || exit 1
    dpkg -i puppet5-release-`lsb_release -c -s`.deb || exit 1
    apt-get update || exit 1
    apt-get install puppet-agent || exit 1
else
    echo "Not Ubuntu or CentOS. Aborting."
    exit 1
fi

# Add puppet to this session's PATH (the installer will sort it for future sessions)
export PATH=$PATH:/opt/puppetlabs/bin

# Find the server we're using

/opt/puppetlabs/bin/puppet config set server $PUPPETMASTER --section main


/opt/puppetlabs/bin/puppet config set masterport $MASTERPORT --section main

# Set the environment

/opt/puppetlabs/bin/puppet config --section agent set environment $PUPPETENV

# If we're setting extra cert attributes, do that now
if [ $SET_EXTRA_ATTRIBUTES ] && [ ${SET_EXTRA_ATTRIBUTES,,} == "y" ]; then
	echo "extension_requests:" >> /etc/puppetlabs/puppet/csr_attributes.yaml
	[ $PP_ENVIRONMENT ] && echo "    pp_environment: $PP_ENVIRONMENT" >> /etc/puppetlabs/puppet/csr_attributes.yaml
	[ $PP_SERVICE ] && echo "    pp_service: $PP_SERVICE" >> /etc/puppetlabs/puppet/csr_attributes.yaml
	[ $PP_ROLE ] && echo "    pp_role: $PP_ROLE" >> /etc/puppetlabs/puppet/csr_attributes.yaml
fi

# Initial puppet run!
/opt/puppetlabs/bin/puppet agent -t

echo "Sign and classify the node on the puppet master, then press enter"
read dummy

# Enable puppet
/opt/puppetlabs/bin/puppet agent --enable

# First real puppet run
/opt/puppetlabs/bin/puppet agent -t || exit 1
