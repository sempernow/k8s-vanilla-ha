#!/usr/bin env bash

echo "  
    =========================================================================
      To setup the provisioner (${GITOPS_USER}), the current user (${USER}) 
      must execute the script below, as shown, at each target node:

          bash create_provisioner_target_node.sh \"\$(cat vm_common.pub)\"

          (Requires root privileges.)
    =========================================================================
"
