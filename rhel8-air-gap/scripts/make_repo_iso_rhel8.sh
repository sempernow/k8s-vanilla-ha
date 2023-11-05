#!/usr/bin/env bash
#############################################################################################
# USAGE : cat yum.repolist.log |cut -d' ' -f1 |xargs -IX ./make_repo_iso_rhel8.sh X
#############################################################################################
[[ $1 ]] || {
    echo "
        This script creates an ISO file of a RHEL repository given its REPOID (\$1). 
        The required downloads may take hours depending on repository size.

        Usage: ./${BASH_SOURCE##*/} REPOID 

        To find REPOID ('repo id') of the desired repository, run: dnf repolist
        "

    exit 1
}

validate(){
    # Validate dependencies else inform and exit
    req=''
    [[ $(type -t createrepo_c) ]] || {
        req="createrepo_c $req"
    }
    [[ $(type -t mkisofs) ]] || {
        req="xorriso $req"
    }
    [[ $(type -t reposync) ]] || {
        req="yum-utils $req"
    }
    [[ $req ]] && {
        echo "
            Run this script again after
            installing its required packages: 
            ---------------------------------
            sudo dnf -y update 
            sudo dnf -y install $req
        "
        return 1
    }
    return 0
}

# Validate dependencies else exit
validate || exit 1

#echo "=== @ '$1'"
#exit

# Download the repo including its metadata
printf "\n%s\n\n" "=== Downloading repo '$1' and its metadata to $(pwd)/"
sudo reposync --gpgcheck --repoid=$1 --download-path=$(pwd) --downloadcomps --downloadonly --download-metadata \
    |& tee $1.reposync.log

# Create repo
printf "\n%s\n\n" "=== Creating repo '$1' at $(pwd)/"
sudo createrepo_c $1 |&tee $1.createrepo_c.log

# Create ISO file
printf "\n%s\n\n" "=== Creating ISO file : '$1.iso' under $(pwd)/"
mkisofs -o $1.iso -R -J -joliet-long $1 |& tee $1.mkisofs.log

exit 0

###################
# Reference only
###################

# Get repo sizes
find . -maxdepth 1 -type d ! -iname '.' -exec du -hs {} \; |tee du.sh.log

# Mount ISO
mnt=/mnt/$1
sudo mkdir -p $mnt
sudo mount -t iso9660 $1.iso $mnt

# Verify ISO content
ls -hl $mnt
