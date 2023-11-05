#!/usr/bin/env bash
#################################################
# Verify/Instruct on HA LB 
#################################################

# # @ firewalld
# echo '=== HA-LB : firewalld settings'
# export zone=public
# export svc=halb
# ansibash -c "
#     sudo firewall-cmd --zone=$zone --list-all
#     sudo firewall-cmd --direct --get-all-rules
#     sudo firewall-cmd --info-service=$svc
# "

echo '=== HA-LB : Verify VIP added to MASTER'
# @ ip : Show addresses of HALB device at each box
echo 'Show VIP added to current keepalived-MASTER node'
ansibash ip -4 -brief addr show $HALB_DEVICE |grep -e === -e $HALB_VIP
# @ nc : Verify connectivity (from admin box)
echo '=== HA-LB : Verify VIP connectivity'
[[ $(type -t nc) ]] && nc -zvw 2 $HALB_VIP $HALB_PORT 2>&1 |grep Connected \
    || echo "Use \`nc -zv $HALB_VIP $HALB_PORT\` to test connectivity"

# @ ping : Verify HALB dynamics (from admin box)
echo '=== HA-LB : Verify failover dynamics'
[[ $(type -t ping) ]] && {
    echo '
        PRESS ENTER when ready to test. 
        
        While ping is running, 
        shutdown the keepalived-MASTER node.

        Connectivity should persist as long as 
        at least one HA-LB node is running.

        CTRL+C to quit.
    '
    read
    ping -4 -D $HALB_VIP
} || echo "Use \`ping -4 -D $HALB_VIP\` to verify failover (HA) when keepalived MASTER node is offline."
