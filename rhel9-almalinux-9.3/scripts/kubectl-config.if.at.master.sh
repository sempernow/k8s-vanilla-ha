#!/usr/bin/env bash
# kubectl config on kubeadm init 
mkdir -p $HOME/.kube
sudo cp -p /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

exit

☩ scp a0:/etc/kubernetes/admin.conf .                              
scp: /etc/kubernetes/admin.conf: Permission denied                 
                                                                   
Ubuntu (master) [15:45:16] [1] [#0] /s/DEV/group1/infra/kubernetes/
☩ ssh sudo cp /etc/kubernetes/admin.conf admin.conf                
ssh: Could not resolve hostname sudo: Name or service not known    
                                                                   
Ubuntu (master) [15:45:48] [1] [#0] /s/DEV/group1/infra/kubernetes/
☩ ssh a0 sudo cp /etc/kubernetes/admin.conf admin.conf             
                                                                   
Ubuntu (master) [15:45:55] [1] [#0] /s/DEV/group1/infra/kubernetes/
☩ scp a0:admin.conf .                                              
scp: admin.conf: Permission denied                                 
                                                                   
Ubuntu (master) [15:46:02] [1] [#0] /s/DEV/group1/infra/kubernetes/
☩ ssh a0 'sudo chown $(id -u):$(id -g) admin.conf'                 
                                                                   
Ubuntu (master) [15:46:37] [1] [#0] /s/DEV/group1/infra/kubernetes/
☩ scp a0:admin.conf .                                              
admin.conf                                                         
                                                                   