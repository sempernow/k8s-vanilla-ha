#---------------------------------------------------------------------
# /etc/haproxy/haproxy.cfg
#
# Documentation : http://www.haproxy.org/download/2.9/doc/
#
# Configure rsyslog @ /etc/rsyslog.d/99-haproxy.conf
#
# See log:
#   sudo cat /var/log/haproxy.log 
#   sudo journalctl -u haproxy.service
#
# MUST KEEP COMMENT LINES: "#  local2.* ..." thru "#log     127.0..."
#---------------------------------------------------------------------

global

    #    local2.*                     /var/log/haproxy.log
    #
        #log        127.0.0.1 local2
        log         /dev/log local0
        
        chroot      /var/lib/haproxy
        pidfile     /var/run/haproxy.pid
        user        haproxy
        group       haproxy
        daemon
        stats       socket /var/lib/haproxy/stats
        maxconn     4000

## Layer 4 (TCP) mode
defaults
    log             global
    mode            tcp
    option          dontlognull
    option          log-health-checks
    option          redispatch
    retries         3
    timeout         connect          5s
    timeout         queue           50s
    timeout         client          50s
    timeout         server          50s
    timeout         http-request    10s
    timeout         http-keep-alive 10s
    timeout         check           10s
    default-server  check inter 10s downinter 5s rise 2 fall 2 slowstart 60s maxconn 250 maxqueue 256 weight 100

## Frontend for K8s API Server
frontend k8s-apiserver
    bind            *:8443
    option          tcplog
    default_backend k8s-apiserver

## Backend for K8s API Server
backend k8s-apiserver
    option      httpchk GET /healthz
    http-check  expect status 200
    option      ssl-hello-chk
    balance     roundrobin
    server      LB_1_FQDN LB_1_IPV4:6443
    server      LB_2_FQDN LB_2_IPV4:6443

## Frontend for K8s Ingress by HTTP
frontend k8s-ingress-http
    bind            *:80
    option          tcplog
    default_backend k8s-ingress-http
    
## Backend for K8s Ingress by HTTP
backend k8s-ingress-http
    option    ssl-hello-chk
    balance   roundrobin
    server    LB_1_FQDN LB_1_IPV4:80
    server    LB_2_FQDN LB_2_IPV4:80

## Frontend for K8s Ingress HTTPS
frontend k8s-ingress-https
    bind            *:443
    option          tcplog
    default_backend k8s-ingress-https
    
## Backend for K8s Ingress HTTPS
backend k8s-ingress-https
    option    ssl-hello-chk
    balance   roundrobin
    server    LB_1_FQDN LB_1_IPV4:443
    server    LB_2_FQDN LB_2_IPV4:443

