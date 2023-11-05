#!/usr/bin/env bash
#################################################
# Verify/Instruct on HA LB 
#################################################

# @ firewalld
echo '=== HA-LB : firewalld settings'
export zone=public
export svc=halb
ansibash -c "
    sudo firewall-cmd --zone=$zone --list-all
    sudo firewall-cmd --direct --get-all-rules
    sudo firewall-cmd --info-service=$svc
"

echo '=== HA-LB : Verify dynamics'
# @ ip : Show 'global' route
echo 'Show VIP : The current keepalived MASTER node'
#ansibash ip -4 addr |grep -e === -e $HALB_VIP
ansibash ip -4 -brief addr show $HALB_DEVICE |grep -e === -e $HALB_VIP

# @ nc : Verify connectivity
echo 'Verify connectivity : nc -zv $HALB_VIP $HALB_PORT'
[[ $(type -t nc) ]] && nc -zv $HALB_VIP $HALB_PORT \
    || echo "Use \`nc -zv $HALB_VIP $HALB_PORT\` to test connectivity"

# @ ping : Verify HA (failover) dynamics
[[ $(type -t ping) ]] && {
    echo '
        Verify FAILOVER (HA) dynamics:
        
        While ping is running, 
        shutdown the keepalived MASTER node.

        Connectivity should persist as long as 
        at least one HA-LB node is running.

        PRESS ENTER when ready to test. 

        Use CTRL+C to kill.
    '
    read
    ping -4 -D $HALB_VIP
} || echo "Use \`ping -4 -D $HALB_VIP\` to verify failover (HA) when keepalived MASTER node is offline."
