#!/usr/bin/env bash

echo '=== Disable Swap memory'
echo '@ swap : BEFORE config'
sudo swapon --show
cat /etc/fstab 
## Disable swap now and forever : required by kubelet
## To find a particular swap, use lsblk 
sudo swapoff -a  # All swaps of /proc/swaps
## #############################################
## >>>  DO NOT disable swap.target (static)  <<<
## #############################################
## Comment out any swap entries of /etc/fstab (once)
## /etc/fstab : unconfigured example 
    ## /dev/mapper/almalinux-root                /          xfs     defaults                   0 0
    ## UUID=0ef0e28d-a54d-4cd6-b7f8-f55b5ca9ae03 /boot      xfs     defaults                   0 0
    ## UUID=B872-847F                            /boot/efi  vfat    umask=0077,shortname=winnt 0 2
    ## /dev/mapper/almalinux-swap                none       swap    defaults                   0 0

# Mod /etc/fstab only if swap-device mount is active (not commented out).
swap_mounted="$(cat /etc/fstab |grep ' swap' |grep -v '^ *#' |awk '{print $1}')"
[[ $swap_mounted ]] && {
    device="$(echo $swap_mounted |awk '{print $1}')"
    sudo sed -i "s,$device,#$device," /etc/fstab
} || { echo '=== swap mount ALREADY commented out'; }

echo '@ swap : AFTER config'
sudo swapon --show
cat /etc/fstab 
sudo systemctl daemon-reload
sudo firewall-cmd --reload

[[ $(getenforce |grep Permissive) ]] && {
echo '=== SELinux : NO CHANGE'
    getenforce
    
    exit 0 
}

# SELinux mod : now and forever
echo '=== SELinux : Set to Permissive'
echo '@ SELinux : BEFORE mod'
getenforce
echo '@ SELinux : Reset/Configure:'
sudo setenforce 0 # set to Permissive (Unreliable)
# "permissive" is "disabled", but logs what would have been if "enforcing".
#sudo sed -i -e 's/^SELINUX=permissive/SELINUX=disabled/' /etc/selinux/config
#sudo sed -i -e 's/^SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
sudo sed -i -e 's/^SELINUX=disabled/SELINUX=permissive/' /etc/selinux/config
sudo sed -i -e 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config
echo '@ SELinux : AFTER mod'
sestatus |grep 'SELinux status'
getenforce


echo '=== REBOOT may be REQUIRED for all changes to take effect.'

exit 0
