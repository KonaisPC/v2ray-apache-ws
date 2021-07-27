# v2ray-apache-websockets
A Script for configuration of v2ray and apache on CentOS and Ubuntu. Break the evil GFW

This script is used on CentOS 7 and Ubuntu 18.04.
Posted from [品葱](https://pincong.rocks/article/1898), and you can find some more specific steps there.

## Disclaimer bugs
Due to some unpredicted problem, there has been a problem configuring the script on Ubuntu server. 
Only tested on Centos/Fedora

## Prerequirements 
1. Complete the bonding of your domain name and VPS IP address on CloudFlare
2. Configure the SSL files (.pem and .key files) on your VPS

## Run this script 
Note: To run this script you must be the root user


<code> git clone https://github.com/KonaisPC/v2ray-apache-ws.git </code>


<code> cd v2ray-apache-ws </code>


<code> bash v2ray-apache.sh </code>

## Things to do after the script 
The script will automatically generate the corresponding client configure json file at ./client.json.
You could copy this file's contents to your client's v2ray configure file and enjoy!
