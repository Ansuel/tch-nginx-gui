#!/bin/sh

install_DGA() {
    #TODO
    echo TODO
}

install_from_github(){
    curl -sLk https://github.com/$1/tarball/$2 --output /tmp/$2.tar.gz
    mkdir /tmp/$2
    tar -xzf /tmp/$2.tar.gz -C /tmp/$2
    rm /tmp/$2.tar.gz
    cd /tmp/$2/*
    chmod +x ./setup.sh
	./setup.sh
	rm -r /tmp/$2
}

device_type="$(uci get -q env.var.prod_friendly_name)"

[ "$(echo $device_type | grep DGA)" ] && install_DGA

[ "$(echo $device_type | grep TG789)" ] && install_from_github FrancYescO/sharing_tg789 amule