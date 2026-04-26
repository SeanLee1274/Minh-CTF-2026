#!/bin/bash
echo "Begin radar..."
while true
do
        ping -c 1 10.1.5.2
        curl -o /dev/null -s -w "Time connect:%{time_connect} Time transfer:%{time_starttransfer} Time total:%{time_total}\n" http://10.1.5.2
        sleep 10
done
