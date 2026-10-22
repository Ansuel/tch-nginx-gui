#!/bin/sh
# Optional Android USB app. MMPBX settings remain part of the core GUI.
archive=/tmp/smartphone.tar.bz2
backup=/opt/modgui-smartphone-gui.tar.gz
owned=/etc/.modgui-smartphone-installed
adb_owned=/etc/.modgui-smartphone-adb-owned
archive_hash=/etc/.modgui-smartphone-archive-sha256
stage=/tmp/modgui-smartphone.$$
files="usr/bin/phone_stats.sh usr/share/transformer/mappings/rpc/smartphone.map www/docroot/modals/smartphone-modal.lp www/docroot/modals/smartphone-screen.lp www/cards/017_smartphone.lp"

set_state() {
    uci set "modgui.app.smartphone_app=$1" && uci commit modgui
}

register_gui() {
    uci -q del_list web.ruleset_main.rules=smartphonemodal
    uci set web.smartphonemodal=rule || return 1
    uci set web.smartphonemodal.target=/modals/smartphone-modal.lp || return 1
    uci -q delete web.smartphonemodal.roles
    uci set web.smartphonescreen=rule || return 1
    uci set web.smartphonescreen.target=/modals/smartphone-screen.lp || return 1
    uci -q delete web.smartphonescreen.roles
    uci -q del_list web.ruleset_main.rules=smartphonescreen
    uci add_list web.smartphonescreen.roles=admin &&
    uci add_list web.smartphonescreen.roles=engineer &&
    uci add_list web.ruleset_main.rules=smartphonescreen &&
    uci add_list web.smartphonemodal.roles=admin &&
    uci add_list web.smartphonemodal.roles=engineer &&
    uci add_list web.ruleset_main.rules=smartphonemodal &&
    uci set web.smartphone_card=card &&
    uci set web.smartphone_card.card=017_smartphone.lp &&
    uci set web.smartphone_card.modal=smartphonemodal &&
    uci commit web
}

unregister_gui() {
    uci -q delete web.smartphone_card
    uci -q delete web.smartphonemodal
    uci -q delete web.smartphonescreen
    uci -q del_list web.ruleset_main.rules=smartphonescreen
    uci -q del_list web.ruleset_main.rules=smartphonemodal
    uci commit web
}

remove_files() {
    for file in $files; do rm -f "/$file"; done
    rm -rf /var/run/modgui-smartphone-screen
}

ensure_adb() {
    command -v adb >/dev/null 2>&1 && return 0
    opkg update || return 1
    # Use the firmware's configured feeds and normal dependency/ABI checks.
    opkg install adb || return 1
    command -v adb >/dev/null 2>&1 || return 1
    printf 'adb\n' > "$adb_owned"
}

restart_gui() {
    /etc/init.d/transformer restart && /etc/init.d/nginx restart
}

rollback() {
    if [ "$changed" = 1 ]; then
        if [ "$was_installed" = 1 ] && [ -f "$backup" ]; then
            tar -xzf "$backup" -C /
            register_gui
            printf '%s\n' "$previous_hash" > "$archive_hash"
            set_state 1
        else
            unregister_gui
            remove_files
            rm -f "$owned" "$archive_hash"
            set_state 0
        fi
        restart_gui
    fi
    if [ "$had_adb_ownership" = 0 ] && [ -f "$adb_owned" ]; then
        opkg remove adb && rm -f "$adb_owned"
    fi
    rm -rf "$stage"
    rm -f "$backup.new"
}

case "$1" in
    install|refresh)
        if [ ! -f "$archive" ] && [ ! -f "$backup" ]; then
            echo "Smartphone app archive is missing; reinstall the GUI package."
            exit 1
        fi
        was_installed=0
        had_adb_ownership=0
        changed=0
        previous_hash=$(cat "$archive_hash" 2>/dev/null)
        [ ! -f "$owned" ] || was_installed=1
        [ ! -f "$adb_owned" ] || had_adb_ownership=1
        if [ "$was_installed" = 0 ]; then
            for file in $files; do
                [ ! -e "/$file" ] || {
                    echo "Refusing to overwrite a pre-existing Smartphone app file: /$file"
                    exit 1
                }
            done
        fi
        (umask 077; mkdir "$stage") || exit 1
        trap rollback EXIT
        trap 'exit 1' HUP INT TERM
        if [ -f "$archive" ]; then
            # Technicolor's BusyBox tar can lack -j even when bzcat is installed.
            bzcat "$archive" > "$stage/payload.tar" || exit 1
            tar -xf "$stage/payload.tar" -C "$stage" || exit 1
            rm -f "$stage/payload.tar"
        else
            tar -xzf "$backup" -C "$stage" || exit 1
        fi
        for file in $files; do
            [ -s "$stage/$file" ] && [ ! -L "$stage/$file" ] || {
                echo "Incomplete Smartphone app archive"
                exit 1
            }
        done
        ensure_adb || exit 1
        mkdir -p /opt || exit 1
        tar -czf "$backup.new" -C "$stage" $files || exit 1
        changed=1
        for file in $files; do
            mkdir -p "$(dirname "/$file")" && cp -p "$stage/$file" "/$file" || exit 1
        done
        chmod 755 /usr/bin/phone_stats.sh || exit 1
        register_gui || exit 1
        touch "$owned" || exit 1
        if [ -f "$archive" ]; then sha256sum "$archive" | awk '{print $1}' > "$archive_hash"; fi
        set_state 1 || exit 1
        restart_gui || exit 1
        mv "$backup.new" "$backup" || exit 1
        trap - EXIT HUP INT TERM
        rm -rf "$stage"
        ;;
    remove)
        [ -f "$owned" ] || { set_state 0; exit $?; }
        # Do not silently strand a reachable VPN-sharing policy on the phone.
        if [ -x /usr/bin/phone_stats.sh ]; then
            stats=$(/usr/bin/phone_stats.sh get_stats 2>/dev/null)
            if printf '%s\n' "$stats" | grep -q '^VPN_SHARE|Attiva$'; then
                /usr/bin/phone_stats.sh stop_vpn || exit 1
            fi
        fi
        if [ -f "$adb_owned" ]; then
            # opkg protects dependencies used by other packages; never force removal.
            opkg remove adb || exit 1
            rm -f "$adb_owned"
        fi
        unregister_gui || exit 1
        remove_files
        rm -f "$owned" "$archive_hash" "$backup"
        set_state 0 || exit 1
        restart_gui
        ;;
    *) echo "usage: smartphoneApp.sh install|remove|refresh" >&2; exit 1 ;;
esac
