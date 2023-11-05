#!/usr/bin/env bash
##############################################################
# Make an ISO of YUM repo ($1) using dnf's reposync method. 
#
# ARGs: repo-id
##############################################################
validate_args()
{
    [[ $1 ]] && return 0 || {
        echo "
            This script creates an ISO file of a RHEL repository given its REPOID (\$1). 
            The required downloads may take hours depending on repository size.

            Usage: ./${BASH_SOURCE##*/} REPOID 

            To find REPOID ('repo id') of the desired repository, run: dnf repolist
        "
        return 1
    }
}
validate_deps()
{
    # Validate dependencies else inform and exit
    req=''
    [[ $(type -t createrepo_c) ]] || {
        req="createrepo_c $req"
    }
    [[ $(type -t genisoimage) ]] || {
        req="genisoimage $req" # xorriso mkisofs
    }
    [[ $(dnf list --installed dnf-plugins-core 2>&1 |grep dnf-plugins-core) ]] || {
        req="dnf-plugins-core $req"
    }
    [[ $req ]] && {
        echo "
            Run this script again after
            installing its required packages: 
            ---------------------------------
            sudo dnf -y update 
            sudo dnf -y install $req
        "
        return 127
    }
    return 0
}
make_iso()
{
    # Make working dir
    mkdir -p repos;cd repos

    # Update else may download stale package version(s)
    printf "\n%s\n\n" "=== Updating repo references"
    sudo dnf -y update 

    # Download the repo including its metadata
    printf "\n%s\n\n" "=== Downloading repo '$1' and its metadata to $(pwd)/"
    sudo dnf reposync --gpgcheck --repoid=$1 --download-path=$(pwd) --downloadcomps --downloadonly --download-metadata

    # Create repo
    printf "\n%s\n\n" "=== Creating repo '$1' at $(pwd)/"
    sudo createrepo_c $1

    # Create ISO file
    printf "\n%s\n\n" "=== Creating ISO file : '$1.iso' under $(pwd)/"
    genisoimage -o $1.iso -R -J -joliet-long $1

    return $?
}

validate_args "$@" || exit $?
validate_deps || exit $?
make_iso "$@"


exit $?
###################
# Reference only
###################

# Mount ISO
mnt=/mnt/$1
sudo mkdir -p $mnt
sudo mount -t iso9660 $1.iso $mnt

# Verify ISO content
ls -hl $mnt
