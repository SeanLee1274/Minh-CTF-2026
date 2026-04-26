while true; do
  ping -c 1 10.1.5.2 -W 10 | grep "time=" || echo "TIMEOUT at $(date +%T)"
  sleep 1
done
