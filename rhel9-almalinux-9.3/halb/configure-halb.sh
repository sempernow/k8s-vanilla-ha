#!/usr/bin/env bash
#################################################
# Configure the HA LB 
#
# See Makefile recipe : lbconf
#################################################
sudo systemctl disable --now keepalived
sudo systemctl disable --now haproxy

# Copy HALB configuration files at a target node : from ssh-user's home to destination 

dir=/usr/lib/systemd/system/keepalived.service.d
sudo mkdir -p $dir
sudo cp 99-keepalived.conf $dir
sudo chmod 0644 $dir/99-keepalived.conf

dir=/etc/keepalived
sudo cp keepalived.conf $dir/keepalived.conf
sudo chmod 0644 $dir/keepalived.conf
sudo cp keepalived-check_apiserver.sh $dir/check_apiserver.sh
sudo chown root:root $dir/check_apiserver.sh
sudo chmod 0744 $dir/check_apiserver.sh

sudo cp haproxy.cfg /etc/haproxy/haproxy.cfg
sudo chmod 0644 /etc/haproxy/haproxy.cfg

sudo cp etc.hosts /etc/hosts 
sudo chmod 0644 /etc/hosts

#sudo cp etc.environment /etc/environment
#sudo chmod 0644 /etc/environment

# Configure HALB logging

sudo cp haproxy-rsyslog.conf /etc/rsyslog.d/99-haproxy.conf 
sudo chmod 0644 /etc/rsyslog.d/99-haproxy.conf 
sudo mkdir -p /var/lib/haproxy/dev

# SELinux
sudo setsebool -P haproxy_connect_any 1

# systemd

sudo systemctl daemon-reload
sudo systemctl restart rsyslog.service
sudo systemctl enable --now keepalived
sudo systemctl enable --now haproxy

#sudo systemctl restart haproxy.service
#sudo systemctl restart keepalived.service

systemctl status haproxy.service |grep Active
systemctl status keepalived.service |grep Active

exit 0
######