#!/usr/bin/env bash

## Environment
set -a  # Export all
vip=192.168.0.100
destination_port=6443

errorExit() { 
	echo "* * * $*" 1>&2
	exit 1
}
set +a  # End export all

## Do
curl --silent --max-time 2 --insecure https://localhost:${destination_port}/ -o /dev/null || errorExit "Error GET https://localhost:${destination_port}/"
if ip addr | grep -q ${vip}; then
	curl --silent --max-time 2 --insecure https://${vip}:${destination_port}/ -o /dev/null || errorExit "Error GET https://${vip}:${destination_port}/"
fi
