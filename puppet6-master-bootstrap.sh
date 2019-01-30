#!/bin/bash

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
    echo "Usage: sudo puppet6-master-bootstrap.sh" 1>&2
    # exit 1
fi

# Do many checks!
if [ ! -f /etc/puppetlabs/puppet/keys/private_key.pkcs7.pem ]; then
    echo "The eyaml private key does not exist in /etc/puppetlabs/puppet/keys/"
    exit 1
fi

if [ ! -f /etc/puppetlabs/puppet/keys/public_key.pkcs7.pem ]; then
    echo "The eyaml public key does not exist in /etc/puppetlabs/puppet/keys/"
    exit 1
fi

if [ ! -f /etc/puppetlabs/r10k/r10k.yaml ]; then
    echo "The r10k config file does not exist at /etc/puppetlabs/r10k/r10k.yaml"
    exit 1
fi

if [ ! -d /root/.ssh ]; then
    mkdir /root/.ssh || exit 1
    chmod 700 /root/.ssh || exit 1
fi

ssh-keyscan github.com >> /root/.ssh/known_hosts || exit 1

echo "Generating new SSH key pair."

ssh-keygen

cat /root/.ssh/id_rsa.pub

read -p "Press enter to continue..."


# Make sure we have a sensible hostname
if [ -z "$NEWHOSTNAME" ]; then
    read -p "Enter a hostname for this machine: " NEWHOSTNAME
fi
echo "Using new hostname from NEWHOSTNAME: $NEWHOSTNAME"
hostname $NEWHOSTNAME
echo $NEWHOSTNAME > /etc/hostname

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

# If we're setting extra cert attributes, do that now
if [ ! -z "$PP_ENVIRONMENT$PP_SERVICE$PP_ROLE" ]; then
    echo "extension_requests:" >> /etc/puppetlabs/puppet/csr_attributes.yaml
    [ $PP_ENVIRONMENT ] && echo "    pp_environment: $PP_ENVIRONMENT" >> /etc/puppetlabs/puppet/csr_attributes.yaml
    [ $PP_SERVICE ] && echo "    pp_service: $PP_SERVICE" >> /etc/puppetlabs/puppet/csr_attributes.yaml
    [ $PP_ROLE ] && echo "    pp_role: $PP_ROLE" >> /etc/puppetlabs/puppet/csr_attributes.yaml
fi


# Make sure the contents of /root/.ssh are owned correctly

chown root:root /root/.ssh/* || exit 1
chmod 0600 /root/.ssh/* || exit 1

echo "Installing Ruby and Git"
apt install ruby git -y || exit 1

echo "Installing r10k"
gem install r10k || exit 1

echo "Running r10k. This WILL take a while..."
/usr/local/bin/r10k deploy environment --puppetfile

echo "Install vault and debouncer for puppet"
/opt/puppetlabs/puppet/bin/gem install vault debouncer || exit 1

echo "Running puppet apply"
cd /etc/puppetlabs/code/environments/production || exit 1
/opt/puppetlabs/bin/puppet apply --hiera_config=/etc/puppetlabs/code/environments/production/hiera.bootstrap.yaml --modulepath="./modules:./ext-redgatemodules/modules:./ext-modules" -e 'include rg_puppetserver' || exit 1

echo "Finished!"