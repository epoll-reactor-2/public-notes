sudo ./eth_lo_create.sh
sudo ip netns exec lb ./xdp_lb veth6 10.0.0.2 de:ad:be:ef:00:02 10.0.0.3 de:ad:be:ef:00:03 &
sudo screen -c screenrc
sudo ip netns pids h2 | sudo xargs -r kill -9
sudo ip netns pids h3 | sudo xargs -r kill -9
sudo ip netns pids lb | sudo xargs -r kill -9
sudo ./eth_lo_destroy.sh
