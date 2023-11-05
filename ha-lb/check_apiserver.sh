apiserver_vip=VIP
apiserver_dest_port=6443

errorExit() { 
	echo "* * * $*" 1>&2
	exit 1
}

curl --silent --max-time 2 --insecure https://localhost:${apiserver_dest_port}/ -o /dev/null || errorExit "Error GET https://localhost:${apiserver_dest_port}/"
if ip addr | grep -q ${apiserver_vip}; then
	curl --silent --max-time 2 --insecure https://${apiserver_vip}:${apiserver_dest_port}/ -o /dev/null || errorExit "Error GET https://${apiserver_vip}:${apiserver_dest_port}/"
fi
