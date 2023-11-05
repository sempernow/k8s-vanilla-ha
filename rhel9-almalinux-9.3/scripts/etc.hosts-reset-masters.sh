#!/usr/bin/env bash

echo '=== /etc/hosts'
cat <<-EOH |sudo tee /etc/hosts
127.0.0.1       localhost $(hostname)
::1             localhost $(hostname)
#192.168.0.92    a0.local
#192.168.0.93    a1.local
EOH
