#!/bin/sh

. /rom/lib/upgrade/platform.sh

overlay_dir=/modoverlay/bank_mod
booted_bank=$(cat /proc/banktable/booted)

base_file_dir=/tmp/rootfile/emergency
root_tmp_dir=/tmp/rootfile

homeware_conversion_tmp=/tmp/homeware_conversion_tmp
homeware_conversion_dir=/overlay/homeware_conversion

logging_file=/tmp/upgrade_logging

echo_log() {
        echo "$@"
        echo "$@" >> $logging_file
}

save_log_and_exit() {
        [ ! -d /overlay/modgui_log ] && mkdir /overlay/modgui_log
        cp $logging_file /overlay/modgui_log/firmware_upgrade_log_$(date +"%H-%M_%m-%d-%y")
        reboot
        exit 1
}

platform_streaming_bank() {
        echo ""
}

copy_base_files() { # <source> <dest>
        preserve_list="/etc/init.d/rootdevice /etc/rc.d/S94rootdevice /usr/sbin/random_seed /sbin/insmod /usr/sbin/mount_modoverlay \
                                  /sbin/mount_root-mod /lib/mount_modroot/05_transfer_basefiles /etc/init.d/do_migrate_overlay \
                                  /lib/upgrade/platform.sh /sbin/sysupgrade /usr/bin/sysupgrade-safe /usr/bin/rtfd"

        for f in $preserve_list; do
                if [ ! -f $f ]; then
                        echo_log "Can't preserve $f. Terminating upgrade!"
                        return 1
                fi
                mkdir -p $2$(dirname "$f")
                cp -a "$1$f" "$2$f"
        done
}

# Preserve file from /
preserve_root() {
        echo_log "Copying GUI package and emergency dir to RAM..."

        mkdir -p $root_tmp_dir $base_file_dir
        if [ -f /root/GUI.tar.bz2 ]; then
                cp /root/GUI.tar.bz2 $root_tmp_dir/
        else
                echo_log "Error in preserving GUI files."
        fi

        copy_base_files "" $base_file_dir

        return $?
}

preserve_config_file() {
        echo_log "Saving root password to modgui file..."
        uci set modgui.var.encrypted_pass="$(awk -F: '/root/ {print $2 }' /etc/shadow)"
        uci commit modgui

        echo_log "Copying config files to homeware_conversion_tmp dir in RAM..."
        mkdir -p $homeware_conversion_tmp
        cp -a $overlay_dir/etc $homeware_conversion_tmp/
        if [ -d $homeware_conversion_tmp/etc ]; then
                echo_log "Config files preserved!"
        else
                echo_log "Config file not copied to RAM!"
        fi
}

postpone_gui_install() {
        echo_log "GUI File found! Good Job!"

        if [ -f $root_tmp_dir/GUI.tar.bz2 ]; then
                echo_log "Restoring GUI.tar.bz2 to allow extraction on next boot"
                mkdir -p $overlay_dir/root
                cp $root_tmp_dir/GUI.tar.bz2 $overlay_dir/root/
                touch $overlay_dir/root/.install_gui            #will be useless if the extraction is not successfull (package missing)
        fi

        echo_log "Setting reapply_due_to_upgrade flag"
        touch $overlay_dir/root/.reapply_due_to_upgrade #needed for shadow password migration and extraction
}

restore_config_File() {
        if [ -d $homeware_conversion_tmp ]; then
                echo_log "Found config dir in RAM!"
                mkdir -p $homeware_conversion_dir

                cp -a $homeware_conversion_tmp/* $homeware_conversion_dir/

                mkdir -p $overlay_dir/etc
                cp -a $homeware_conversion_tmp/etc/config/modgui $overlay_dir/etc/modgui_old

                echo_log "Config files restored to homeware conversion dir! File will be updated on next boot."
        fi
}

restore_base_root() {
        echo_log "Rooting file not found! Using emergency method."
        mkdir -p $overlay_dir
        cp -a $base_file_dir/* $overlay_dir/
        echo_log "Device Rooted"
}

platform_do_upgrade() {

        touch $logging_file

        # If /modoverlay is not mounted, use bank_2 overlay
        if ! mount | grep -q /modoverlay; then
                overlay_dir=/overlay/$booted_bank
        else
                # Update files in modroot
                /etc/init.d/do_migrate_overlay preserve_files
        fi

        preserve_root

        if [ $? -ne 0 ] || [ ! -f $base_file_dir/etc/init.d/rootdevice ]; then
                echo_log "Error in preserving root files."
                save_log_and_exit
        fi

        echo_log "Base Files preserved!"
        [ "$SAVE_CONFIG" != "0" ] && preserve_config_file

        # Reset overlay dir
        [ -d $overlay_dir ] && rm -r $overlay_dir/*

        # Make sure modoverlay is empty
        if [ "$(ls -A $overlay_dir)" ]; then
                restore_base_root
                echo_log "Running on dirty config... This could cause bootloop... Restoring file and restarting!"
                save_log_and_exit
        fi

        if [ "$ROOT_ONLY" != "1" ]; then
                check_dir=$overlay_dir/root/GUI.tar.bz2
                postpone_gui_install
        else
                check_dir=$overlay_dir/etc/init.d/rootdevice
                restore_base_root
        fi

        [ "$SAVE_CONFIG" != "0" ] && restore_config_File

        if platform_is_dualbank; then
                if [ -f $check_dir ]; then

                        if mount | grep -q /modoverlay; then
                                # As last step update base in original bank_2 overlay
                                echo_log "Update base file in original /overlay"
                                copy_base_files $base_file_dir /overlay/$booted_bank
                                      [ -d /proc/prozone ] && {
                                        # Simulate the bank_1 failed 3 times
                                        echo 1 > /proc/prozone/bootfail
                                        echo 2 > /proc/prozone/bootcounter
                                        echo 0 > /proc/prozone/bootbank
                                      }
                        fi

                        platform_do_upgrade_bank $1 $booted_bank || exit 1
                else
                        echo_log "Rooting file not present in new config! Aborting... "
                        restore_base_root
                        save_log_and_exit
                fi
        else
                # Not supported keep old code, no modem found with single bank with firmware based on openwrt
                platform_do_upgrade_bank $1 bank_1 || exit 1
                mkdir -p /overlay/homeware_conversion
        fi
}
