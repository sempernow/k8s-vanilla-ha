#!/usr/bin env bash
# Create system user/group provisioner at admin/control machine
#
# This script is idempotent.
#
u=gitops 

# Create system group if not exist
[[ $(getent group $u) ]] || sudo groupadd -r $u

# Create system user having home directory and no login shell if user not exist
[[ "$(id -un $u 2>/dev/null)" == $u ]] || sudo useradd -r -m -g $u -s /bin/false $u

# Generate SSH key pair for user if user's private key not exist
key=/home/$u/.ssh/id_ed25519
sudo ls $key || sudo -u $u ssh-keygen -t ed25519 -N '' -C "$u@$(hostname)" -f $key

exit 0
##################################################
# Example use case, where $u is 'gitops'
#
#  Setup a systemd service (a_svc_name.service) 
#  configured to run as 'gitops' user/group:
##################################################

sudo chown gitops:gitops /path/to/the_binary
sudo chown -R gitops:gitops /path/to/required/directory

sudo chmod 0755 /path/to/the_binary
sudo chmod -R 0755 /path/to/required/directory

# Regarding /path/to/..., :
# Binaries installed by the pkg manager are under /etc/bin/.
# Manually installed binaries NOT of a service are under /etc/local/bin/ .
# Manaully installed binaries of a service should be under either
# /etc/local/bin/a_svc_name/, /opt/a_svc_name/, or /srv/a_svc_name/.

# Create the systemd Unit file 
# @ /etc/systemd/system/a_svc_name.service :

# [Unit]
# Description=A GitOps service running as user/group 'gitops'
# After=network.target

# [Service]
# User=gitops
# Group=gitops
# ExecStart=/path/to/the_binary

# [Install]
# WantedBy=multi-user.target
