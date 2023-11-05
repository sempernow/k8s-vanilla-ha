#!/usr/bin/env bash

# UPDATE : Move this Swap disable section to post-env.sh
# to allow Swap during pkgs install, else small machines choke.

## Configure local DNS (once) : self recognition only
[[ $(cat /etc/hosts |grep $(hostname)) ]] && { 
    echo '=== /etc/hosts : ALREADY CONFIGURED'
    cat /etc/hosts
    
    exit 
} 
echo '=== /etc/hosts'
cat <<-EOH |sudo tee /etc/hosts
127.0.0.1 localhost $(hostname)
::1       localhost $(hostname)
EOH
