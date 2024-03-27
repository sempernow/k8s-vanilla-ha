## /etc/keepalived/keepalived.conf
## See : man keepalived.conf
## SET MODE to 0644 if user is root
# See @ https://kubesphere.io/docs/v3.4/installing-on-linux/high-availability-configurations/set-up-ha-cluster-using-keepalived-haproxy/

global_defs {
    enable_script_security
    router_id K8S_DEV
    max_auto_priority 50
    default_interface SET_DEVICE
    # @ kubesphere.io
    vrrp_skip_check_adv_addr
    #vrrp_garp_interval 0
    #vrrp_gna_interval 0
}

vrrp_script check_apiserver {
    #script "/etc/keepalived/check_apiserver.sh"
    script "/usr/bin/killall -0 haproxy"
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
    #promote_secondaries
    
    authentication {
        auth_type PASS
        auth_pass SET_PASS
    }
    
    # Use subnet-CIDR mask : See: ip -brief -4 addr
    virtual_ipaddress {
        SET_VIP/SET_MASK
    }

    # Unicast instead of default Multicast
    unicast_src_ip THIS_IP
    
    unicast_peer {
        UNICAST_PEER_1    
        UNICAST_PEER_2    
        UNICAST_PEER_3    
    }
    
    track_script {
        check_apiserver
    }

}
