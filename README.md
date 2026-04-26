# CTF-Team-2-2026 
__Useful command for Red Team__
#See Processes running
ps aux | grep hping3 | grep -v grep | wc -l
#Kill hping3 processes
sudo pkill hping3
