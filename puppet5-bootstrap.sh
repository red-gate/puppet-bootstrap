#!/bin/bash

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "Usage: sudo puppet5-bootstrap.sh" 1>&2
   exit 1
fi

# Make sure we have a sensible hostname
echo "Enter a hostname: "
read NEWHOSTNAME
hostname $NEWHOSTNAME
echo $NEWHOSTNAME > /etc/hostname


# Download and install puppet
mkdir setup-temp
cd setup-temp
wget https://apt.puppetlabs.com/puppet5-release-`lsb_release -c -s`.deb || exit 1
dpkg -i puppet5-release-`lsb_release -c -s`.deb || exit 1
apt-get update || exit 1
apt-get install puppet-agent || exit 1

# Add puppet to this session's PATH (the installer will sort it for future sessions)
export PATH=$PATH:/opt/puppetlabs/bin

# Find the server we're using
echo "Enter puppet master hostname: "
read PUPPETMASTER
/opt/puppetlabs/bin/puppet config set server $PUPPETMASTER --section main

echo "Enter puppet master port (8140 is the normal one): "
read MASTERPORT
/opt/puppetlabs/bin/puppet config set masterport $MASTERPORT --section main

# Set the environment
echo "Enter environment name: "
read PUPPETENV
/opt/puppetlabs/bin/puppet config set environment $PUPPETENV

# Initial puppet run!
/opt/puppetlabs/bin/puppet agent -t

echo "Sign and classify the node on the puppet master, then press enter"
read dummy

# Enable puppet
/opt/puppetlabs/bin/puppet agent --enable

# First real puppet run
/opt/puppetlabs/bin/puppet agent -t || exit 1
