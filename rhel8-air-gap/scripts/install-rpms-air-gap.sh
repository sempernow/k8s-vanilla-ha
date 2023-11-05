#!/usr/bin/env bash
#
# VM provisioning : install RPMs 
#
# Install some packages and then reboot
# to prevent out-of-memory errors that otherwise occur
# due to shortcomings of dynamic memory allocation.

# UPDATE : Tested @ RHEL 9.3 (Prior edit @ AlmaLinux 8.9)

# Nexus : Yum Repositories
# https://help.sonatype.com/en/yum-repositories.html


[[ -d "$1" ]] || {
    echo "USAGE : $BASH_SCRIPT /path/to/rpm/files"

    echo "RPMs : $1"
    exit 10
}

pushd $1

## VM provisioned with OS + repos
# [[ $(dnf repolist |grep -i $epel) ]] || {
#     echo "REQUIREs repo : $epel"

#     exit 20
# }

echo '=== Install all packages (*.rpm)'

mkdir -p logs
log="logs/dnf.install.rpms.$(date '+%Y-%m-%d.%H.%M').log"

[[ -d docker-ce.repo ]] && {
    sudo dnf -y config-manager --add-repo docker-ce.repo |& tee $log
}
#sudo dnf -y update 
#sudo dnf -y makecache

#sudo rpm -ivh *.rpm |& tee -a $log
sudo dnf -y install --nobest --allowerasing --disablerepo=* *.rpm |& tee -a $log
# find . -type f -iname '*.rpm' -exec sudo dnf -y install --nobest --allowerasing --disablerepo=* {} \; \
#     |& tee -a $log

popd 

exit 0


