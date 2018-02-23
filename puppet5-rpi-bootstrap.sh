#!/bin/bash

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "Usage: sudo puppet5-bootstrap.sh" 1>&2
   exit 1
fi

# Make sure we have a sensible hostname
echo "Enter a hostname for this machine: "
read NEWHOSTNAME
hostname $NEWHOSTNAME
echo $NEWHOSTNAME > /etc/hostname

echo "Enter the puppetmaster hostname"
read MASTER

echo "Enter puppet master port (8140 is the normal one): "
read MASTERPORT

echo "Enter the environment name"
read PUPPETENV

echo "Thanks. Beginning set up. This compiles from source so will likely take a long time..."
# add puppet repo
mkdir setup-temp
cd setup-temp

apt-get update || exit 1
apt-get install ruby-full facter hiera bundler unzip -y || exit 1

wget https://github.com/puppetlabs/puppet/archive/5.4.0.zip || exit 1
unzip 5.4.0.zip || exit 1
cd puppet-5.4.0

bundle install --path .bundle/gems || exit 1
bundle update || exit 1
ruby install.rb || exit 1

# Add puppet path for future sessions

cat >> /etc/profile.d/puppetpath.sh << \EOF
    PATH=$PATH:/opt/puppetlabs/bin
EOF

# Add puppet path for this session
export PATH=$PATH:/opt/puppetlabs/bin || exit 1

puppet config set server $MASTER --section main || exit 1

puppet config set masterport $MASTERPORT --section main

puppet config set environment $PUPPETENV --section main || exit 1

puppet agent -t

echo 'Sign this node on the master and press [enter] here when done...'
read dummy

# Enable puppet
puppet agent --enable

# Run it for reals
puppet agent -t

# Enable the service
puppet resource service puppet ensure=running enable=true
