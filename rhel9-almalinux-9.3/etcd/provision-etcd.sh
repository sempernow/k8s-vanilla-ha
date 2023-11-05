#!/bin/bash
# Install etcd

# This script requires its PWD to be its own directory.
cd "${BASH_SOURCE%/*}"

set -a  # EXPORT ALL ...

# Environment
[[ $1 ]] && {
    ssh_configured_hosts="$@"
} || {
    echo "REQUIREs the list of ssh-configured machines to provision." 
    echo "USAGE : ${0##*/} VM1 VM2 ..." 
    exit
}

_ssh() { 
    mode=$1;shift
    for vm in $ssh_configured_hosts
    do
        echo "=== @ $vm : $1 $2 $3 ..."
        [[ $mode == '-s' ]] && ssh $vm "/bin/bash -s" < "$@"
        [[ $mode == '-c' ]] && ssh $vm "/bin/bash -c" "$@"
        [[ $mode == '-x' ]] && ssh $vm "$@"
        [[ $mode == '-u' ]] && scp -p "$1" "$vm:$1"
        [[ $mode == '-d' ]] && scp -p "$vm:$1" "$vm_$1"
    done 
}

set +a  # END EXPORT ALL ...

_ssh -s 'etcd-install.sh'

# Test
#_ssh -s 'etcd-test.sh'
_ssh -x "nohup etcd > etcd.log 2>&1 &"
### Write
_ssh -x 'etcdctl --endpoints=localhost:2379 put foo bar'
### Read
_ssh -x 'etcdctl --endpoints=localhost:2379 get foo'
### Stop etcd server
_ssh -x "
    kill \$(ps aux |grep etcd |grep Sl |grep -v grep |awk '{print \$2}') \
    || kill \$(ps aux |grep etcd |grep Ssl |grep -v grep |awk '{print \$2}')
"