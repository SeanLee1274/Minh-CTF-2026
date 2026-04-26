for i in {1..20}; do
  sudo hping3 -I eth1 --rand-source -2 -p 12345 -d 1400 --flood 10.1.5.2 &
done
read
sudo pkill hping3
