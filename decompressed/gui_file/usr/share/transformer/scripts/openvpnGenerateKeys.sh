#!/bin/sh

set -e
umask 077
mkdir -p /etc/openvpn
if [ -d /opt/modgui-openvpn-openssl/usr/lib ]; then
    export LD_LIBRARY_PATH=/opt/modgui-openvpn-openssl/usr/lib
fi

required_keys_present() {
    for file in ca.crt server.crt server.key client.crt client.key dh2048.pem; do
        [ -s "/etc/openvpn/$file" ] || return 1
    done
}

required_keys_present && exit 0

if command -v easyrsa >/dev/null 2>&1; then
    work="/etc/openvpn/easy-rsa-pki"
    rm -rf "$work"
    mkdir -p "$work"
    cd "$work"
    EASYRSA_PKI="$work/pki" easyrsa --batch init-pki
    EASYRSA_PKI="$work/pki" easyrsa --batch --req-cn=modgui-openvpn-ca build-ca nopass
    EASYRSA_PKI="$work/pki" easyrsa --batch --req-cn=server gen-req server nopass
    EASYRSA_PKI="$work/pki" easyrsa --batch sign-req server server
    EASYRSA_PKI="$work/pki" easyrsa --batch --req-cn=client gen-req client nopass
    EASYRSA_PKI="$work/pki" easyrsa --batch sign-req client client
    EASYRSA_PKI="$work/pki" easyrsa --batch gen-dh
    cp "$work/pki/ca.crt" /etc/openvpn/ca.crt
    cp "$work/pki/issued/server.crt" /etc/openvpn/server.crt
    cp "$work/pki/private/server.key" /etc/openvpn/server.key
    cp "$work/pki/issued/client.crt" /etc/openvpn/client.crt
    cp "$work/pki/private/client.key" /etc/openvpn/client.key
    cp "$work/pki/dh.pem" /etc/openvpn/dh2048.pem
elif [ -x /etc/easy-rsa/2.0/pkitool ]; then
    cd /etc/easy-rsa/2.0
    . ./vars
    ./clean-all
    ./pkitool --initca
    ./pkitool --server server
    ./pkitool client
    openssl dhparam -out keys/dh2048.pem 2048
    cp keys/ca.crt keys/server.crt keys/server.key keys/client.crt keys/client.key keys/dh2048.pem /etc/openvpn/
else
    echo "No supported easy-rsa runtime found" >&2
    exit 1
fi

chmod 600 /etc/openvpn/server.key /etc/openvpn/client.key
required_keys_present
