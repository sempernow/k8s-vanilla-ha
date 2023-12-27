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
    state SLAVE
    interface eth0
    virtual_router_id 151
    priority 254
    authentication {
        auth_type PASS
        auth_pass 5b803224-bf37-46f1-ae78-f49a7ebedd8a
    }
    virtual_ipaddress {
        192.168.0.100/24
    }
    track_script {
        check_apiserver
    }
}
