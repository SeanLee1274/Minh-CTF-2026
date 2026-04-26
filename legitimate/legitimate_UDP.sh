while true; do
  dig @10.1.5.2 google.com +short
  echo "[$(date +%T)] DNS query sent"
  sleep 1
done
