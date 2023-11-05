#!/usr/bin/env bash
########################################################
# Disable all swaps 
# - Idempotent.
########################################################
[[ $(cat /proc/swaps |grep -v Filename) ]] || {
    echo '== All swaps are already disabled'
    exit 0
} 

echo '=== Disable Swap memory'

echo '@ swap : BEFORE'
sudo swapon --show
cat /etc/fstab |grep swap
## Disable swap now and forever : required by kubelet
## To find a particular swap, use lsblk 
sudo swapoff -a  # Disable all swaps of /proc/swaps
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

echo '@ swap : AFTER'

sudo swapon --show
cat /etc/fstab |grep swap
sudo systemctl daemon-reload
sudo firewall-cmd --reload
