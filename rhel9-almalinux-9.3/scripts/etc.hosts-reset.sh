#!/usr/bin/env bash

echo '=== /etc/hosts'
cat <<-EOH |sudo tee /etc/hosts
127.0.0.1       localhost $(hostname)
::1             localhost $(hostname)
EOH
