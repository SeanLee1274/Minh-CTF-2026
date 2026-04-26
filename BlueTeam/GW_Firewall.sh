!/bin/bash

echo -n "Starting firewall: "
IPTABLES="/sbin/iptables"
$IPTABLES --flush
$IPTABLES -t raw -F

# Interfaces
MGMT_IF="eth0"               # SPHERE-console (172.30.0.0/16)
RETH="eth2"                  # router/client→gateway link (10.1.1.3)
SETH="eth1"                  # server/gateway→server link (10.1.5.3)

# Always allow loopback (local processes)
$IPTABLES -A INPUT  -i lo -j ACCEPT
$IPTABLES -A OUTPUT -o lo -j ACCEPT

# Default-DROP posture
$IPTABLES -P INPUT   DROP    # drop any ingress to gateway not explicitly allowed
$IPTABLES -P FORWARD DROP    # drop any transit traffic not explicitly allowed
$IPTABLES -P OUTPUT  ACCEPT  # gateway may always initiate outbound connections

# example: block client1 source traffic to GW
# $IPTABLES -t filter -A INPUT -s 10.1.2.2 -j DROP

# example: block client1 source traffic to Server
#$IPTABLES -A FORWARD -i $RETH -o $SETH -s 10.1.2.2 -d 10.1.5.2 -j DROP


# Drop IP fragments immediately
$IPTABLES -t raw -A PREROUTING -f -j DROP

# Anti-spoof: block packets claiming to be from your own IPs
$IPTABLES -A INPUT   -i $RETH -s 10.1.5.3 -j DROP
$IPTABLES -A INPUT   -i $SETH -s 10.1.1.3 -j DROP

# Create whitelist chain
$IPTABLES -N VALID_CLIENTS

# Allow known clients
$IPTABLES -A VALID_CLIENTS -s 10.1.2.2 -j RETURN
$IPTABLES -A VALID_CLIENTS -s 10.1.3.2 -j RETURN
$IPTABLES -A VALID_CLIENTS -s 10.1.4.2 -j RETURN

# Drop everyone else
$IPTABLES -A VALID_CLIENTS -j DROP

# Apply to traffic going to server
$IPTABLES -A FORWARD -i $RETH -o $SETH -d 10.1.5.2 -j VALID_CLIENTS


# Drop truly malformed packets
$IPTABLES -A INPUT   -m conntrack --ctstate INVALID   -j DROP
$IPTABLES -A FORWARD -m conntrack --ctstate INVALID   -j DROP
# Make sure no fragmented packets
$IPTABLES -A INPUT -f -j DROP
$IPTABLES -A FORWARD -f -j DROP


# Port-scan / malformed TCP drops
$IPTABLES -A FORWARD -i $RETH -o $SETH \
  -p tcp --tcp-flags ALL NONE -j DROP
$IPTABLES -A FORWARD -i $RETH -o $SETH \
  -p tcp --tcp-flags ALL ALL  -j DROP

# Block SYN-ACK flood attacks
$IPTABLES -A FORWARD -i $RETH -o $SETH -p tcp --tcp-flags SYN,ACK SYN,ACK -j DROP

# Block invalid TCP flag combinations
$IPTABLES -A FORWARD -i $RETH -o $SETH -p tcp --tcp-flags FIN,SYN FIN,SYN -j DROP
$IPTABLES -A FORWARD -i $RETH -o $SETH -p tcp --tcp-flags SYN,RST SYN,RST -j DROP
$IPTABLES -A FORWARD -i $RETH -o $SETH -p tcp --tcp-flags SYN,FIN SYN,FIN -j DROP
$IPTABLES -A FORWARD -i $RETH -o $SETH -p tcp --tcp-flags FIN,RST FIN,RST -j DROP
$IPTABLES -A FORWARD -i $RETH -o $SETH -p tcp --tcp-flags FIN,ACK FIN -j DROP
$IPTABLES -A FORWARD -i $RETH -o $SETH -p tcp --tcp-flags ACK,URG URG -j DROP
$IPTABLES -A FORWARD -i $RETH -o $SETH -p tcp --tcp-flags ACK,FIN FIN -j DROP
$IPTABLES -A FORWARD -i $RETH -o $SETH -p tcp --tcp-flags ACK,PSH PSH -j DROP


# Allow established/related in both chains
# moved line 123 here
$IPTABLES -A FORWARD -i $RETH -o $SETH -p tcp --sport 0:1023 -d 10.1.5.2 --dport 80 -m limit --limit 5/minute -j ACCEPT
#$IPTABLES -A FORWARD -i $RETH -o $SETH -p tcp --sport 0:1023 -d 10.1.5.2 --dport 80 -j DROP
$IPTABLES -A INPUT   -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
$IPTABLES -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Permit management SSH *only* from SPHERE console on eth0
$IPTABLES -A INPUT -i $MGMT_IF -p tcp --dport 22 -m conntrack --ctstate NEW -j ACCEPT

# Anti-spoof: block packets claiming to be from your own IPs
#    Ingress to gateway host:
#$IPTABLES -A INPUT   -i $RETH -s 10.1.5.3 -j DROP
#$IPTABLES -A INPUT   -i $SETH -s 10.1.1.3 -j DROP

# Transit packets:
$IPTABLES -A FORWARD -i $RETH -o $SETH -s 10.1.5.3 -j DROP
$IPTABLES -A FORWARD -i $SETH -o $RETH -s 10.1.1.3 -j DROP

# Rate-limit ICMP (ping) to gateway itself
$IPTABLES -A INPUT -i $RETH -p icmp --icmp-type echo-request -m limit --limit 1/second --limit-burst 5 -j ACCEPT
$IPTABLES -A INPUT -i $RETH -p icmp --icmp-type echo-request -j DROP

# through to the server
$IPTABLES -A FORWARD -i $RETH -o $SETH -p icmp --icmp-type echo-request -m limit --limit 1/second --limit-burst 5 -j ACCEPT
$IPTABLES -A FORWARD -i $RETH -o $SETH -p icmp --icmp-type echo-request -j DROP

# allow echo-replies back out
$IPTABLES -A OUTPUT -p icmp --icmp-type echo-reply -j ACCEPT

## New SYN flood protection
$IPTABLES -A FORWARD -i $RETH -o $SETH -p tcp -d 10.1.5.2 --dport 80 --syn -m limit --limit 20/second --limit-burst 40 -j ACCEPT
$IPTABLES -A FORWARD -i $RETH -o $SETH -p tcp --dport 80 --syn -j DROP

# Forward only HTTP/HTTPS to your server
$IPTABLES -A FORWARD -i $RETH -o $SETH -p tcp -d 10.1.5.2 --dport 80 -m conntrack --ctstate NEW -j ACCEPT
$IPTABLES -A FORWARD -i $RETH -o $SETH -p tcp -d 10.1.5.2 --dport 443 -m conntrack --ctstate NEW -j ACCEPT

# SYN-flood protection - old
#$IPTABLES -A FORWARD -i $RETH -o $SETH -p tcp --dport 80 --syn -m limit --limit 20/second --limit-burst 40 -j ACCEPT
#$IPTABLES -A FORWARD -i $RETH -o $SETH -p tcp --dport 80 --syn -j DROP

# Block all UDP traffic (complete blocking instead of rate-limiting)
$IPTABLES -A FORWARD -i $RETH -o $SETH -p udp -j DROP

# Port-scan / malformed TCP drops
#$IPTABLES -A FORWARD -i $RETH -o $SETH \
#  -p tcp --tcp-flags ALL NONE -j DROP
#$IPTABLES -A FORWARD -i $RETH -o $SETH \
#  -p tcp --tcp-flags ALL ALL  -j DROP

# Block SYN-ACK flood attacks
#$IPTABLES -A FORWARD -i $RETH -o $SETH -p tcp --tcp-flags SYN,ACK SYN,ACK -j DROP

# Block invalid TCP flag combinations
#$IPTABLES -A FORWARD -i $RETH -o $SETH -p tcp --tcp-flags FIN,SYN FIN,SYN -j DROP
#$IPTABLES -A FORWARD -i $RETH -o $SETH -p tcp --tcp-flags SYN,RST SYN,RST -j DROP
#$IPTABLES -A FORWARD -i $RETH -o $SETH -p tcp --tcp-flags SYN,FIN SYN,FIN -j DROP
#$IPTABLES -A FORWARD -i $RETH -o $SETH -p tcp --tcp-flags FIN,RST FIN,RST -j DROP
#$IPTABLES -A FORWARD -i $RETH -o $SETH -p tcp --tcp-flags FIN,ACK FIN -j DROP
#$IPTABLES -A FORWARD -i $RETH -o $SETH -p tcp --tcp-flags ACK,URG URG -j DROP
#$IPTABLES -A FORWARD -i $RETH -o $SETH -p tcp --tcp-flags ACK,FIN FIN -j DROP
#$IPTABLES -A FORWARD -i $RETH -o $SETH -p tcp --tcp-flags ACK,PSH PSH -j DROP

# Protect against Slowloris attack
$IPTABLES -A FORWARD -i $RETH -o $SETH -p tcp -d 10.1.5.2 --dport 80 \
  -m connlimit --connlimit-above 20 --connlimit-mask 24 -j DROP

# Teardrop attack protection
$IPTABLES -A FORWARD -i $RETH -o $SETH -p tcp -m tcpmss ! --mss 536:65535 -j DROP

# Block packets with payload size over threshold (potential DDoS)
$IPTABLES -A FORWARD -i $RETH -o $SETH -p tcp -m length --length 1000:65535 -m limit --limit 10/minute -j LOG --log-prefix "OVERSIZED TCP: "
$IPTABLES -A FORWARD -i $RETH -o $SETH -p tcp -m length --length 1000:65535 -j DROP

# Protections against ACK+PSH    ########## CHECK THIS ONE ######### I think fine cause no legit doing this on this exp
$IPTABLES -A FORWARD -p tcp --tcp-flags ACK,PSH ACK,PSH -m limit --limit 30/s --limit-burst 60 -j DROP

# Window size protections
# $IPTABLES -A FORWARD -p tcp -m u32 --u32 "0>>22&0x3C@14&0xFFFF:>65535" -j DROP

# 18) Protect against TCP RST attacks
$IPTABLES -A FORWARD -i $RETH -o $SETH -p tcp --tcp-flags RST RST \
  -m limit --limit 2/second --limit-burst 5 -j ACCEPT
$IPTABLES -A FORWARD -i $RETH -o $SETH -p tcp --tcp-flags RST RST -j DROP

# Limit HTTP GET flood (rate-limit total established HTTP connections)
$IPTABLES -A FORWARD -i $RETH -o $SETH -p tcp -d 10.1.5.2 --dport 80 -m state --state ESTABLISHED \
  -m limit --limit 20/second --limit-burst 50 -j ACCEPT

#### maybe earlier? #### Moved the commented line earlier
# Protect against source port spoofing (limit unusual source ports)
#$IPTABLES -A FORWARD -i $RETH -o $SETH -p tcp --sport 0:1023 -d 10.1.5.2 --dport 80 -m limit --limit 5/minute -j ACCEPT
$IPTABLES -A FORWARD -i $RETH -o $SETH -p tcp --sport 0:1023 -d 10.1.5.2 --dport 80 -j DROP

# Session tracking - limit total concurrent connections per source IP
$IPTABLES -A FORWARD -i $RETH -o $SETH -p tcp -d 10.1.5.2 --dport 80 \
  -m connlimit --connlimit-above 15 --connlimit-mask 32 -j DROP

######## CHECK ######### flip these two?
# HTTP Request rate limiting per source IP (prevent application layer attacks)
$IPTABLES -A FORWARD -i $RETH -o $SETH -p tcp -d 10.1.5.2 --dport 80 \
  -m state --state ESTABLISHED,RELATED \
  -m recent --name HTTP --set
$IPTABLES -A FORWARD -i $RETH -o $SETH -p tcp -d 10.1.5.2 --dport 80 \
  -m state --state ESTABLISHED,RELATED \
  -m recent --name HTTP --update --seconds 1 --hitcount 5 -j DROP

####### move earlier? ########
# Hashlimit to allow fair usage across all clients (prevents one IP from dominating)
$IPTABLES -A FORWARD -i $RETH -o $SETH -p tcp -d 10.1.5.2 --dport 80 \
  -m hashlimit --hashlimit-name HTTP --hashlimit-mode srcip --hashlimit-srcmask 24 \
  --hashlimit-above 5/second --hashlimit-burst 10 --hashlimit-htable-expire 60000 -j DROP

