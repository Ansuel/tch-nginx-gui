@echo off

bash -c "cd decompressed/base && tar -cf - * | bzip2 -9 -c - > ../../compressed/base.tar.bz2"
bash -c "cd decompressed/gui_file && tar -cf - * | bzip2 -9 -c - > ../../compressed/gui_file.tar.bz2"
bash -c "cd decompressed/telnet_support-specificDGA && tar -cf - * | bzip2 -9 -c - > ../../compressed/telnet_support-specificDGA.tar.bz2"
bash -c "cd decompressed/traffic_mon && tar -cf - * | bzip2 -9 -c - > ../../compressed/traffic_mon.tar.bz2"
bash -c "cd decompressed/upnpfix-specificDGA && tar -cf - * | bzip2 -9 -c - > ../../compressed/upnpfix-specificDGA.tar.bz2"
bash -c "cd decompressed/upgrade-pack-specificDGA && tar -cf - * | bzip2 -9 -c - > ../../compressed/upgrade-pack-specificDGA.tar.bz2"
bash -c "cd decompressed/custom-ripdrv && tar -cf - * | bzip2 -9 -c - > ../../compressed/custom-ripdrv.tar.bz2"
bash -c "rm -r total"
bash -c "mkdir total"
bash -c "cp -dr decompressed/base/* total && cp -dr decompressed/gui_file/* total && cp -dr decompressed/custom-ripdrv/* total && cp -dr decompressed/upgrade-pack-specificDGA/* total && cp -dr decompressed/telnet_support-specificDGA/* total && cp -dr decompressed/traffic_mon/* total && cp -dr decompressed/upnpfix-specificDGA/* total"
bash -c "cd total && tar -cf - * | bzip2 -9 -c - > ../compressed/GUI_dev.tar.bz2"
bash -c "./update-version_dev.sh"