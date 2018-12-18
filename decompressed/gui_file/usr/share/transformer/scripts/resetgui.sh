#!/bin/sh
#
#	 Custom Gui for Technicolor Modem: utility script and modified gui for the Technicolor Modem
#	 								   interface based on OpenWrt
#
#    Copyright (C) 2018  Christian Marangi <ansuelsmth@gmail.com>
#
#    This file is part of Custom Gui for Technicolor Modem.
#    
#    Custom Gui for Technicolor Modem is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#    
#    Custom Gui for Technicolor Modem is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#    
#    You should have received a copy of the GNU General Public License
#    along with Custom Gui for Technicolor Modem.  If not, see <http://www.gnu.org/licenses/>.
#
#

rm -r /www/*
rm /etc/nginx/nginx.conf
rm -r /usr/share/transformer/*
rm -r /usr/lib/lua/transformer/*
rm -r /usr/lib/lua/web/*

cp -r /rom/www/* 			/www/
cp /rom/etc/nginx/nginx.conf 	   	/etc/nginx/nginx.conf
cp -r /rom/usr/share/transformer/* 	/usr/share/transformer/
cp -r /rom/usr/lib/lua/transformer/* 	/usr/lib/lua/transformer/
cp -r /rom/usr/lib/lua/web/* 		/usr/lib/lua/web/

/etc/init.d/rootdevice force
