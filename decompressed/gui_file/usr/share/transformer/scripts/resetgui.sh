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
