#!/bin/bash

domain=unifi.example.com
renew_expire_date=15;

le_path="/etc/letsencrypt"
cert_file="/etc/letsencrypt/live/$domain/fullchain.pem"
conf_path="$le_path/renewal/$domain.conf"

certbot_path="$le_path/certbot-auto"
update_script="$le_path/scripts/unifi_le_ssl_import.sh"


printf "
[DEBUG] Domain: $domain
[DEBUG] Renew if time til expiration is less than $renew_expire_date days
[DEBUG] le_path $le_path
[DEBUG] cert_file $cert_file
[DEBUG] conf_path $conf_path 
[DEBUG] certbot_path $certbot_path
[DEBUG] update_script $update_script \n\n"


printf "[INFO] Checking if Certificate file exists. \n"
if [ ! -f $cert_file ]; then
	printf "[ERROR] Certificate file not found for domain $domain.\n\n"
	exit 1;
else
	printf "[INFO] Certificate file found!\n\n"
fi

exp=$(date -d "`openssl x509 -in $cert_file -text -noout|grep "Not After"|cut -c 25-`" +%s)
printf "[DEBUG] Expires at: $exp\n"

datenow=$(date -d "now" +%s)
printf "[DEBUG] Current date: $datenow\n"

days_exp=$(echo \($exp - $datenow\) / 86400 | bc)
printf "[DEBUG] Days until expiration: $days_exp\n\n"

printf "[INFO] Checking if expiration date for $domain needs to be renewed\n"

if [ "$days_exp" -gt "$renew_expire_date" ] ; then
	printf "[INFO] The certificate is up to date, no need for renewal ($days_exp days left).\n\n"
	exit 0;
else
	printf "[INFO] The certificate for $domain will expire in $days_exp. Attempting Renewal.\n"
	( exec $certbot_path "renew" "--standalone" "--force-renewal" )
	printf "[INFO] Renewed certificates, now running update script!\n"
	( exec "$update_script" )
	#TODO: Add checks here.
	printf "Renewal process completed for domain $domain\n\n"
	exit 0;
fi
