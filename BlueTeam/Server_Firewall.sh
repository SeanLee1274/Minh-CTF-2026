#!/bin/bash

echo -n "Applying server protections: "
IPTABLES="/sbin/iptables"

# Interface definitions
MGMT_IFACE="eth0"            # SPHERE console / management
SERVER_IFACE="eth1"          # gateway -> server link

$IPTABLES -A INPUT -i lo -j ACCEPT
$IPTABLES -A OUTPUT -o lo -j ACCEPT
# 1) Clear any old rules so previous lockout rules are removed
$IPTABLES -F
$IPTABLES -X
$IPTABLES -t raw -F
$IPTABLES -t raw -X

# 2) Keep policies open on the server to avoid lockout
$IPTABLES -P INPUT ACCEPT
$IPTABLES -P OUTPUT ACCEPT
$IPTABLES -P FORWARD DROP

# 3) Never let the server forward traffic
#    This is safe because the server should not be routing for anyone.
$IPTABLES -A FORWARD -j DROP

# 4) Enable SYN-cookie protections against SYN floods
sysctl -w net.ipv4.tcp_syncookies=1
sysctl -w net.ipv4.tcp_max_syn_backlog=4096
sysctl -w net.ipv4.tcp_synack_retries=3

# 5) Keepalive / timeout tuning to reduce long-lived abusive connections
sysctl -w net.ipv4.tcp_fin_timeout=15
sysctl -w net.ipv4.tcp_keepalive_time=600

# 6) Drop clearly invalid packets
$IPTABLES -A INPUT -m conntrack --ctstate INVALID -j DROP

# 7) Drop IP fragments early
$IPTABLES -t raw -A PREROUTING -f -j DROP

# 8) Block obviously malformed scan packets
$IPTABLES -A INPUT -p tcp --tcp-flags ALL NONE -j DROP
$IPTABLES -A INPUT -p tcp --tcp-flags ALL ALL -j DROP
$IPTABLES -A INPUT -p tcp --tcp-flags ALL FIN,PSH,URG -j DROP
$IPTABLES -A INPUT -p tcp --tcp-flags SYN,FIN SYN,FIN -j DROP
$IPTABLES -A INPUT -p tcp --tcp-flags SYN,RST SYN,RST -j DROP
$IPTABLES -A INPUT -p tcp --tcp-flags FIN,RST FIN,RST -j DROP

# 9) Drop oversized inbound TCP packets to the web service
$IPTABLES -A INPUT -i $SERVER_IFACE -p tcp --dport 80 -m length --length 1000:65535 -j DROP

# 10) Light web-filtering for known attack-tool strings
#     These drop obvious slowhttptest traffic without restricting normal browsers.
$IPTABLES -A INPUT -i $SERVER_IFACE -p tcp --dport 80 -m string --string "slowhttptest" --algo bm -j DROP
$IPTABLES -A INPUT -i $SERVER_IFACE -p tcp --dport 80 -m string --string "DDoS" --algo bm -j DROP

# 11) Log suspicious drops at a controlled rate for debugging
$IPTABLES -A INPUT -m limit --limit 20/minute -j LOG --log-prefix "SERVER-PROTECT: " --log-level 7

# 12) Start simple performance monitoring snapshots in the background
#     These are safe to ignore if you do not need them.
mkdir -p /tmp/server_monitor

nohup sh -c 'while true; do \
  date >> /tmp/server_monitor/load.log; \
  uptime >> /tmp/server_monitor/load.log; \
  ss -ant state syn-recv >> /tmp/server_monitor/syn_recv.log; \
  ss -ant | grep ":80 " >> /tmp/server_monitor/http_connections.log; \
  sleep 5; \
done' >/dev/null 2>&1 &

echo "done."
