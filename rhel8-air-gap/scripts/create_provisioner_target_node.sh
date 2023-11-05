#!/usr/bin env bash
# - Create regular user/group on (remote) target machine 
#   - User account has password login disabled (locked),
#     so key-based ssh login is the only way in
#     that isn't root.
# - Add an ssh-public-key string to that (remote) user's 
#   ~/.ssh/authorize_keys file to allow access by 
#   the (local) user having its private-key pair.
#
# ARGs: <ssh public key (string)>
#
# This script is idempotent.
# 
u=gitops
silent='' # yes
unset is_already
[[ "$(id -un $u 2>/dev/null)" == "$u" ]] && is_already=1
[[ "$is_already" ]] || sudo useradd -m -s /bin/bash $u
sudo passwd -l $u # Lock the acount, disabling password login.
#[[ $is_already ]] || openssl rand -base64 33 |sudo passwd $u --stdin
[[ "$(getent group $u)" ]] || sudo groupadd $u
[[ "$(groups $u |grep $u)" ]] || sudo usermod -aG $u $u
# Allow for root access sans password 
echo "$u ALL=(ALL) NOPASSWD: ALL" |sudo tee /etc/sudoers.d/$u

# Setup SSH PKI for any user by appending their public-key string
# to authorized_keys file of the created user ($u) at target node.
[[ "$@" ]] || {
    [[ "$silent" == 'yes' ]] && exit 1
    echo "
        | USAGE : $BASH_SOURCE "$(sudo cat ~/.ssh/id_ed25519.pub)"
        |
        | This example configures local user ($USER) as ssh user ($u) at remote target.
    "
    exit 1
}
# Append a user's public-key string ($@) to ~/.ssh/authorized_keys file of user $u.
key_str="$@" 
file=/home/$u/.ssh/authorized_keys
[[ -f $file ]] && [[ $(cat $file |grep "$key_str") ]] && {
    [[ "$silent" == 'yes' ]] && exit 0
    echo "The provided SSH key already exists in $file ."
    exit 0
}
sudo -u $u mkdir -p /home/$u/.ssh
sudo -u $u chmod 0700 /home/$u/.ssh
echo "$key_str" |sudo -u $u tee -a $file
sudo -u $u chmod 0600 $file
