#!/usr/bin/env bash
#################################################
# SELinux : Set to permissive (now and forever)
# - Idempotent
#################################################
[[ $(cat /etc/selinux/config |grep SELINUX=enforcing) || $(cat /etc/selinux/config |grep SELINUX=disabled) ]] || {
    echo '== SELinux is already set to permissive'
    exit 0
} 


echo '=== SELinux : Set to Permissive'

echo '@ SELinux : BEFORE'

getenforce
echo '@ SELinux : Reset/Configure:'
sudo setenforce 0 # set to Permissive : Unreliable and does NOT persist.
# "permissive" is "disabled", but logs what would have been if "enforcing".
#sudo sed -i -e 's/^SELINUX=permissive/SELINUX=disabled/' /etc/selinux/config
#sudo sed -i -e 's/^SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
sudo sed -i -e 's/^SELINUX=disabled/SELINUX=permissive/' /etc/selinux/config
sudo sed -i -e 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config

echo '@ SELinux : AFTER'

sestatus |grep 'SELinux status'
getenforce

echo '=== REBOOT may be REQUIRED for SELinux changes to take effect.'


