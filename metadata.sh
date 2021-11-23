#! /bin/bash
if [[ -f /etc/startup_was_launched ]]; then exit 0; fi

sudo apt-get -y install unzip
sudo apt -y install nodejs 
sudo apt -y install npm
sudo apt-get -y install python3

touch /etc/startup_was_launched