#!/bin/bash
file="/var/log/suricata/fast.log"
while true
do

        if [ -s "$file" ]; then
                echo "$(date '+%Y-%m-%d %H:%M:%S') ==ALERTS=="
                sudo cat "$file"
                sudo truncate -s 0 /var/log/suricata/fast.log
                sleep 5
        else
                echo "$(date '+%Y-%m-%d %H:%M:%S') NO Alerts"
                sleep 5
        fi

done
