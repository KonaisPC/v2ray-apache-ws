#!/bin/bash 
# This is a script for the configuration of v2ray and apache on CentOS 7
# I'll be appreciated If you are interested in modifing the simple demo to help us improve the 
# ability! 

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

judgetOsType() {
  if ! [ -f /etc/os-release ]; then
    >&2 echo "Error, /etc/os-release doesn't exist" 
    exit 1
  fi

  . /etc/os-release 
  os=$ID
}

judgeIsRootUser() {
  if [[ $EUID -ne 0 ]]; then
   >&2 echo "Sorry, this script must be run as root" 
   exit 1
  fi
}

# Judge installation tool 
judgeInstallationTool() {
  if [ "$os" == "centos" ]; then
    install=yum
  else 
    install=apt
  fi
}

userInput() {
  echo -e "V2ray & Apache Configuration Script"
  echo -e "Your OS type is $os \n\n"
  echo -e "Please input your ${RED}domain name${NC}:"
  read domainName 

  echo -e "Then please specify the absolute path(/etc/example.pem) that your ${RED}.pem${NC} file exists(the file must contains the contents of 'Origin Certificate' from CloudFlare): "
  read pemFile

  if ! [ -f $pemFile ]; then
  >&2 echo "Sorry, $pemFile doesn't exist. Please try again" 
    exit 2
  fi

  echo -e "Please specify the absolute path(/etc/example.key) that your ${RED}.key${NC} file exists(the file must contains the contents of 'Private Key' from CloudFlare): "
  read keyFile 

  if ! [ -f $keyFile ]; then
  >&2 echo "Sorry, $keyFile doesn't exist. Please try again" 
    exit 2
  fi
}


# Install Apache on CentOS
installApacheOnCentos() {
  yum install httpd -y
  yum install mod_ssl -y
}

# Install Apache on Ubuntu 
installApacheOnUbuntu() {
  apt install apache2 -y
  a2enmod ssl
}

installApache() {
  if [ "$os" == "centos" ]; then
    installApacheOnCentos
  else 
    installApacheOnUbuntu
  fi
}

# Write configuration contents to Apache 
configureApache() {
  if [ "$os" == "centos" ]; then 
    apacheConfigureFile="/etc/httpd/conf.d/${domainName}.conf"
  else
    apacheConfigureFile="/etc/apache2/sites-available/${domainName}.conf"

    rm -rf /etc/apache2/sites-available/*
  fi

  cat > $apacheConfigureFile << EOF
  <VirtualHost *:80>

          Servername $domainName

          RewriteEngine on

          RewriteCond %{SERVER_NAME} =$domainName 

          RewriteRule ^ https://%{SERVER_NAME}%{REQUEST_URL} [END,NE,R=permanent]

  </VirtualHost>

  <VirtualHost *:443>

          Servername $domainName 

          SSLEngine on

          SSLCertificateFile $pemFile

          SSLCertificateKeyFile $keyFile

          RewriteEngine On

          RewriteCond %{HTTP:Upgrade} =websocket [NC]

          RewriteRule /(.*)      ws://localhost:12345/$1 [P,L]

          RewriteCond %{HTTP:Upgrade} !=websocket [NC]

          RewriteRule /(.*)      http://localhost:12345/$1 [P,L]

          SSLProxyEngine On

          ProxyPass /ws http://localhost:12345

          ProxyPassReverse /ws http://127.0.0.1:12345

  </VirtualHost>
EOF
}


# Restart and enable the apache daemon 
restartAndEnableApache() {
  if [ "$os" == "centos" ]; then
    apache=httpd
  else 
    apache=apache2
  fi

  systemctl restart $apache
  systemctl enable $apache
}

# Configure the firewall
configureFirewall() {
  firewall-cmd --permanent --add-service=https
  firewall-cmd --reload 
}

# Install V2ray
installV2ray() {
  $install install curl -y
  # Official V2ray installation script 
  bash <(curl -L -s https://install.direct/go.sh)

  # Generate random UUID number for v2ray
  uuid=$(cat /proc/sys/kernel/random/uuid)

  # Configure V2ray
  v2rayConfigureFile=/etc/v2ray/config.json
  cat > $v2rayConfigureFile << EOF
  {
    "inbounds": [{
      "port": 12345,
      "listen": "127.0.0.1",
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": $uuid,
            "level": 1,
            "alterId": 64
          }
        ]
      },
      "streamSettings": {
          "network": "ws",
          "wsSettings": {
              "path": "/ws"
          }
      }
    }],
    "outbounds": [{
      "protocol": "freedom",
      "settings": {}
    },{
      "protocol": "blackhole",
      "settings": {},
      "tag": "blocked"
    }],
    "routing": {
      "rules": [
        {
          "type": "field",
          "ip": ["geoip:private"],
          "outboundTag": "blocked"
        }
      ]
    }
  }
EOF

  # Restart and enable v2ray daemon
  systemctl restart v2ray
  systemctl enable v2ray
}

# Output your corresponding client v2ray configure contents to ./client.json
outputClientJsonFile() {
  cat > ./client.json << EOF
  {
"inbounds": [
{
"port": 1080,
"listen": "127.0.0.1",
"protocol": "socks",
"settings": {
"udp": true
}
}
],
"outbounds": [
{
"protocol": "vmess",
"settings": {
"vnext": [
{
"address": "${domainName}",
"port": 443,
"users": [
{
"id": "$uuid",
"level": 1,
"alterId": 64,
"security": "auto"
}
]
}
]
},
"streamSettings": {
"network": "ws",
"security": "tls",
"tlsSettings": {
"serverName": "$domainName",
"allowInsecure": true
},
"wsSettings": {
"path": "\/ws"
}
},
"mux": {
"enabled": true
}
},
{
"protocol": "freedom",
"tag": "direct",
"settings": {}
}
],
"routing": {
"domainStrategy": "IPOnDemand",
"rules": [
{
"type": "field",
"ip": [
"geoip:private"
],
"outboundTag": "direct"
}
]
}
}
EOF

}


conclude() {
  echo -e "\n\n\n${GREEN}Great! Configuration Success!${NC}"
  echo Your domain name is: $domainName
  echo -e "Your ${RED}uuid(id)${NC} is: $uuid"
  echo -e "Your corresponding ${RED}client v2ray configuration json file${NC} has been created at ./client.json($(pwd)/client.json)"
  echo Enjoy! All men are created equal!
}

main() {
  judgeIsRootUser
  judgetOsType
  judgeInstallationTool

  userInput

  installApache
  configureApache
  restartAndEnableApache

  configureFirewall

  installV2ray
  outputClientJsonFile
  conclude
}

main
