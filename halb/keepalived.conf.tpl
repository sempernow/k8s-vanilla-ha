## /etc/keepalived/keepalived.conf
## Configuration File for keepalived
## See man keepalived.conf

global_defs {
    enable_script_security
    router_id LVS_DEVEL
    max_auto_priority 100
}

vrrp_script check_apiserver {
  script "/etc/keepalived/check_apiserver.sh"
  interval 3
  weight -2
  fall 10
  rise 2
}

vrrp_instance VI_1 {
    state MASTER
    interface SET_DEVICE
    virtual_router_id 151
    priority 255
    authentication {
        auth_type PASS
        auth_pass SET_PASS
    }
    virtual_ipaddress {
        SET_VIP/24
    }
    track_script {
        check_apiserver
    }
}
