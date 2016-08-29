#!/bin/bash

# SIGTERM-handler
term_handler() {
    if [ $pid -ne 0 ]; then
        echo "Term signal catched. Shutdown supervisord and disable iptables rules..."
        kill -SIGTERM "$pid"
        wait "$pid"
        iptables-save | grep -v REDSOCKS | iptables-restore
    fi
    exit 143; # 128 + 15 -- SIGTERM
}

# setup handler
trap 'kill ${!}; term_handler' SIGTERM

# Cleanup iptables
iptables-save | grep -v REDSOCKS | iptables-restore

# First we added a new chain called 'REDSOCKS' to the 'nat' table.
iptables -t nat -N REDSOCKS

# Set proxy exceptions for docker0 bridge
iptables -t nat -A REDSOCKS -d 0.0.0.0/8 -j RETURN
iptables -t nat -A REDSOCKS -d 10.0.0.0/8 -j RETURN
iptables -t nat -A REDSOCKS -d 127.0.0.0/8 -j RETURN
iptables -t nat -A REDSOCKS -d 169.254.0.0/16 -j RETURN
iptables -t nat -A REDSOCKS -d 172.16.0.0/12 -j RETURN
iptables -t nat -A REDSOCKS -d 192.168.0.0/16 -j RETURN
iptables -t nat -A REDSOCKS -d 224.0.0.0/4 -j RETURN
iptables -t nat -A REDSOCKS -d 240.0.0.0/4 -j RETURN
iptables -t nat -A REDSOCKS -p tcp -j REDIRECT --to-ports 16800

# Finally we tell iptables to use the ‘REDSOCKS’ chain for all outgoing connection in the network interface ‘eth0′.
iptables -t nat -A PREROUTING -p tcp -j REDSOCKS
iptables -t nat -A OUTPUT -p tcp -m tcp --dport 53 -j REDSOCKS

supervisord -n &
pid="$!"
while true
do
  sleep 1 & wait ${!}
done

