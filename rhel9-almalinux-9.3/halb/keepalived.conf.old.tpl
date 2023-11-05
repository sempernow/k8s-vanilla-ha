## /etc/keepalived/keepalived.conf
## See : man keepalived.conf
## SET MODE to 0644 if user is root

global_defs {
    enable_script_security
    router_id K8S_DEV
    max_auto_priority 20
    default_interface SET_DEVICE
}

vrrp_script check_apiserver {
    script "/etc/keepalived/check_apiserver.sh"
    user root
    interval 2
    # The weight: + applies (adds to priority) only on exit 0; - applies only on exit > 0. 
    weight -10
    fall 3
    rise 3
}

vrrp_instance VI_1 {
    state MASTER
    interface SET_DEVICE
    virtual_router_id 151
    priority 255
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass SET_PASS
    }
    virtual_ipaddress {
        SET_VIP/24
    }
    #promote_secondaries
    track_script {
        check_apiserver
    }
}
