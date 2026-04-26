#!/bin/bash

sudo tshark -l -i eth1 \
-Y "tcp.flags.syn==1 || tcp.flags.fin==1 || http.request || icmp.type==8 || udp" \
-T fields -E separator=, \
-e tcp.stream -e frame.time_epoch -e tcp.flags -e ip.src -e ip.dst -e http.request.method -e http.host -e http.request.uri \
-e icmp.type -e icmp.seq -e udp.srcport -e udp.dstport \
| awk -F, '
{
    stream=$1
    time=$2
    flags=$3
    src=$4
    dst=$5
    reqmeth=$6
    pge=$7
    uri=$8
    icmp_type=$9
    icmp_seq=$10
    udp_src=$11
    udp_dst=$12

    if (flags == "0x00000002") {
        start[stream]=time
        source_ip[stream]=src
        dst_ip[stream]=dst
    }
    if (reqmeth!= ""){
        req_meth[stream]=reqmeth
        page[stream]=pge
        uridata[stream]=uri
    }
    if (icmp_type=="8"){
        print "PING:", src, "->", dst, "seq:", icmp_seq
    }
    if (udp_src != "" || udp_dst != ""){
        print "UDP traffic: ", src "->", dst, "Ports:", udp_src, "->", udp_dst
    }
    if ((flags == "0x00000001" || flags == "0x00000011") && (stream in start)) {
        Duration = time-start[stream]
        print "Stream", stream, \
        source_ip[stream], "->", dst_ip[stream], \
        "Duration:", Duration, "sec", \
        "http data:", req_meth[stream], page[stream], uridata[stream], "page"
        delete start[stream]
        delete source_ip[stream]
        delete dst_ip[stream]
        delete req_meth[stream]
        delete page[stream]
        delete uridata[stream]
    }
}
'
