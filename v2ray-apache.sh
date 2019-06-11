#!/bin/bash 
# This is a script for the configuration of v2ray and apache on CentOS 7
# I'll be appreciated If you are interested in modifing the simple demo to help us improve the 
# ability! 


echo -e "V2ray & Apache Configuration Script\n\n"
echo Please input your domain name: 
read domainName 

echo "Then please specify the path that your .pem file exists( the file must contains the contents of 'Origin Certificate' from CloudFlare ): "
read pemFile

echo "Please specify the path that your .key file exists( the file must contains the contents of 'Private Key' from CloudFlare ): "
read keyFile

# Configure Apache 
yum install httpd -y
yum install mod_ssl -y

# Write configuration contents to file
apacheConfigureFile="/etc/httpd/conf.d/${domainName}.conf"
/bin/cat > $apacheConfigureFile << EOF
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

# Restart and enable the apache daemon 
systemctl restart httpd 
systemctl enable httpd 

# Configure the firewall
firewall-cmd --permanent --add-service=https
firewall-cmd --reload 

yum install curl -y

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

echo -e "\n\n\nGreat! Configuration Success!"
echo Your domain name is: $domainName
echo Your uuid is: $uuid
echo Enjoy! All men are created equal!