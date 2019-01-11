#!/bin/bash

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "Usage: sudo puppet6-bootstrap.sh" 1>&2
   # exit 1
fi

# Make sure we have a sensible hostname
if [ -z "$NEWHOSTNAME" ]; then
    read -p "Enter a hostname for this machine: " NEWHOSTNAME
fi
echo "Using new hostname from NEWHOSTNAME: $NEWHOSTNAME"
hostname $NEWHOSTNAME
echo $NEWHOSTNAME > /etc/hostname

if [ -z "$PUPPETMASTER" ]; then
    read -p "Enter puppet master hostname: " PUPPETMASTER
fi
echo "Using puppet master: $PUPPETMASTER"

if [ -z "$MASTERPORT" ]; then
    read -p "Enter puppet master port (8140 is the normal one): " MASTERPORT
fi
echo "Using master port: $MASTERPORT"

if [ -z "$PUPPETENV" ]; then
    read -p "Enter Puppet environment name: " PUPPETENV
fi
echo "Using puppet environment: $PUPPETENV"

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

# Download and install puppet
mkdir setup-temp
cd setup-temp

dist=`awk -F= '/^NAME/{print $2}' /etc/os-release`

if [ "$dist" == "\"CentOS Linux\"" ]; then
    version=`awk -F= '/^VERSION_ID/{print $2}' /etc/os-release`
    wget https://yum.puppetlabs.com/puppet6/puppet6-release-el-${version//\"}.noarch.rpm || exit 1
    rpm -Uvh puppet5-release-el-${version//\"}.noarch.rpm || exit 1
    yum update || exit 1
    yum install puppet-agent -y || exit 1
elif [ "$dist" == "\"Ubuntu\"" ]; then
	RELEASE_NAME=`lsb_release -c -s`
    wget https://apt.puppetlabs.com/puppet6-release-${RELEASE_NAME}.deb || exit 1
    dpkg -i puppet6-release-${RELEASE_NAME}.deb || exit 1
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
if [ ! -z "$PP_ENVIRONMENT$PP_SERVICE$PP_ROLE" ]; then
	echo "extension_requests:" >> /etc/puppetlabs/puppet/csr_attributes.yaml
	[ $PP_ENVIRONMENT ] && echo "    pp_environment: $PP_ENVIRONMENT" >> /etc/puppetlabs/puppet/csr_attributes.yaml
	[ $PP_SERVICE ] && echo "    pp_service: $PP_SERVICE" >> /etc/puppetlabs/puppet/csr_attributes.yaml
	[ $PP_ROLE ] && echo "    pp_role: $PP_ROLE" >> /etc/puppetlabs/puppet/csr_attributes.yaml
fi

# Initial puppet run!
/opt/puppetlabs/bin/puppet agent -t

if [ -z "$NO_WAIT_FOR_SIGN" ]; then
    echo "Sign and classify the node on the puppet master, then press enter"
    read dummy

    # First real puppet run
    /opt/puppetlabs/bin/puppet agent -t || exit 1
fi

# Enable puppet
/opt/puppetlabs/bin/puppet agent --enable