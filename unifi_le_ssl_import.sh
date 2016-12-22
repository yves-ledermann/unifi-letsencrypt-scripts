#!/bin/bash

UNIFI_HOSTNAME=unifi.babb.tech
UNIFI_DIR=/usr/lib/unifi
UNIFI_SERVICE_NAME=unifi
LE_LIVE_DIR=/etc/letsencrypt/live
PRIV_KEY=/etc/ssl/private/hostname.example.com.key
SIGNED_CRT=/etc/ssl/certs/hostname.example.com.crt
CHAIN_FILE=/etc/ssl/certs/startssl-chain.crt
KEYSTORE=${UNIFI_DIR}/data/keystore
ALIAS=unifi
PASSWORD=aircontrolenterprise
PRIV_KEY=${LE_LIVE_DIR}/${UNIFI_HOSTNAME}/privkey.pem
SIGNED_CRT=${LE_LIVE_DIR}/${UNIFI_HOSTNAME}/cert.pem
CHAIN_FILE=${LE_LIVE_DIR}/${UNIFI_HOSTNAME}/chain.pem

printf "\nInspecting current SSL certificate...\n"
if md5sum -c ${LE_LIVE_DIR}/${UNIFI_HOSTNAME}/cert.pem.md5 &>/dev/null; then
	printf "\nCertificate is unchanged, no update is necessary.\n"
	exit 0
else
	printf "\nUpdated SSL certificate available. Proceeding with import...\n"
fi


if [ ! -f ${PRIV_KEY} ] || [ ! -f ${SIGNED_CRT} ] || [ ! -f ${CHAIN_FILE} ]; then
	printf "\nMissing one or more required files. Check your settings.\n"
	exit 1
else
	printf "\nImporting the following files:\n"
	printf "Private Key: %s\n" "$PRIV_KEY"
	printf "Signed Certificate: %s\n" "$SIGNED_CRT"
	printf "CA File: %s\n" "$CHAIN_FILE"
fi

P12_TEMP=$(mktemp)
CA_TEMP=$(mktemp)

# Stop the UniFi Controller
printf "\nStopping UniFi Controller...\n"
/etc/init.d/${UNIFI_SERVICE_NAME} stop


# Write a new MD5 checksum based on the updated certificate	
printf "\nUpdating certificate MD5 checksum...\n"
md5sum ${LE_LIVE_DIR}/${UNIFI_HOSTNAME}/cert.pem > ${LE_LIVE_DIR}/${UNIFI_HOSTNAME}/cert.pem.md5 
cat > "${CA_TEMP}" <<'_EOF'
-----BEGIN CERTIFICATE-----
MIIDSjCCAjKgAwIBAgIQRK+wgNajJ7qJMDmGLvhAazANBgkqhkiG9w0BAQUFADA/
MSQwIgYDVQQKExtEaWdpdGFsIFNpZ25hdHVyZSBUcnVzdCBDby4xFzAVBgNVBAMT
DkRTVCBSb290IENBIFgzMB4XDTAwMDkzMDIxMTIxOVoXDTIxMDkzMDE0MDExNVow
PzEkMCIGA1UEChMbRGlnaXRhbCBTaWduYXR1cmUgVHJ1c3QgQ28uMRcwFQYDVQQD
Ew5EU1QgUm9vdCBDQSBYMzCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEB
AN+v6ZdQCINXtMxiZfaQguzH0yxrMMpb7NnDfcdAwRgUi+DoM3ZJKuM/IUmTrE4O
rz5Iy2Xu/NMhD2XSKtkyj4zl93ewEnu1lcCJo6m67XMuegwGMoOifooUMM0RoOEq
OLl5CjH9UL2AZd+3UWODyOKIYepLYYHsUmu5ouJLGiifSKOeDNoJjj4XLh7dIN9b
xiqKqy69cK3FCxolkHRyxXtqqzTWMIn/5WgTe1QLyNau7Fqckh49ZLOMxt+/yUFw
7BZy1SbsOFU5Q9D8/RhcQPGX69Wam40dutolucbY38EVAjqr2m7xPi71XAicPNaD
aeQQmxkqtilX4+U9m5/wAl0CAwEAAaNCMEAwDwYDVR0TAQH/BAUwAwEB/zAOBgNV
HQ8BAf8EBAMCAQYwHQYDVR0OBBYEFMSnsaR7LHH62+FLkHX/xBVghYkQMA0GCSqG
SIb3DQEBBQUAA4IBAQCjGiybFwBcqR7uKGY3Or+Dxz9LwwmglSBd49lZRNI+DT69
ikugdB/OEIKcdBodfpga3csTS7MgROSR6cz8faXbauX+5v3gTt23ADq1cEmv8uXr
AvHRAosZy5Q6XkjEGB5YGV8eAlrwDPGxrancWYaLbumR9YbK+rlmM6pZW87ipxZz
R8srzJmwN0jP41ZL9c8PDHIyh8bwRLtTcm1D9SZImlJnt1ir/md2cXjbDaJWFBM5
JDGFoqgCWjBH4d1QB7wCCZAA62RjYJsWvIjJEubSfZGL+T0yjWW06XyxV3bqxbYo
Ob8VZRzI9neWagqNdwvYkQsEjgfbKbYK7p2CNTUQ
-----END CERTIFICATE-----
_EOF

if [ -s "${KEYSTORE}.orig" ]; then
	printf "\nBackup of original keystore exists!\n"
	printf "\nCreating non-destructive backup as keystore.bak...\n"
	cp ${KEYSTORE} ${KEYSTORE}.bak
else
	cp ${KEYSTORE} ${KEYSTORE}.orig
	printf "\nNo original keystore backup found.\n"
	printf "\nCreating backup as keystore.orig...\n"
fi
	 
printf "\nExporting SSL certificate and key data into temporary PKCS12 file...\n"
openssl pkcs12 -export \
-in ${SIGNED_CRT} \
-inkey ${PRIV_KEY} \
-CAfile ${CHAIN_FILE} \
-out ${P12_TEMP} -passout pass:${PASSWORD} \
-caname root -name ${ALIAS}
	
printf "\nRemoving previous certificate data from UniFi keystore...\n"
keytool -delete -alias ${ALIAS} -keystore ${KEYSTORE} -deststorepass ${PASSWORD}
	
printf "\nImporting SSL certificate into UniFi keystore...\n"
keytool -importkeystore \
-srckeystore ${P12_TEMP} -srcstoretype PKCS12 \
-srcstorepass ${PASSWORD} \
-destkeystore ${KEYSTORE} \
-deststorepass ${PASSWORD} \
-destkeypass ${PASSWORD} \
-alias ${ALIAS} -trustcacerts
	
printf "\nImporting certificate authority into UniFi keystore...\n\n"
java -jar ${UNIFI_DIR}/lib/ace.jar import_cert \
${SIGNED_CRT} \
${CHAIN_FILE} \
${CA_TEMP}

printf "\nRemoving temporary files...\n"
rm -f ${P12_TEMP}
rm -f ${CA_TEMP}
	
printf "\nRestarting UniFi Controller to apply new Let's Encrypt SSL certificate...\n"
/etc/init.d/${UNIFI_SERVICE_NAME} start

printf "\nDone!\n"

exit 0
