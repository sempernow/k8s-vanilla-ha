#!/usr/bin/env bash
# Test ansible-playbook syntax and dynamics

echo $(pwd) |tee foo.log

exit 0


echo '=== sudo journalctl'         |& tee -a foo.log
sudo journalctl -r --lines=10 |& tee -a foo.log

echo "$(utc)"                 |tee -a foo.log
echo "hostname: $(hostname)"  |tee -a foo.log

exit 0 


echo "Got: 1: '$1', 2: '$2'"  |tee -a foo.log

echo '=== ls @ sudoers.d'         |& tee -a foo.log
ls -hal /etc/sudoers.d/       |tee -a foo.log
echo '=== ls @ PWD'               |tee -a foo.log
ls -hal .                     |tee -a foo.log

echo '=== sudo journalctl'         |& tee -a foo.log
sudo journalctl -r --lines=10 |& tee -a foo.log

exit 0
