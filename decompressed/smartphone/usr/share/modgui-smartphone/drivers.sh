#!/bin/sh
# Use each firmware's configured feeds and normal opkg compatibility checks.
# Shared USB network dependencies are retained when the app is removed.
status_file=/etc/modgui-smartphone-drivers.status
boot_file=/etc/modules.d/60-modgui-smartphone-net
module_dir=/lib/modules/$(uname -r)
reboot_file=/tmp/modgui-smartphone-drivers-reboot

report() {
    message=$1
    [ ! -f "$reboot_file" ] || message="$message Please reboot the router to use updated USB drivers."
    printf '%s\n' "$message" > "$status_file"
    printf '%s\n' "$message"
}
installed() { opkg status "$1" 2>/dev/null | grep -q '^Status: .* installed$'; }
version() { opkg status "$1" 2>/dev/null | sed -n 's/^Version: //p'; }
available() { printf '%s\n' "$catalog" | awk -v name="$1" '$1 == name {found=1} END {exit !found}'; }
module_file() {
    # Firmware modules may be flat or under kernel/drivers/net/usb.
    find "$module_dir" -type f \( -name "$1.ko" -o -name "$1.ko.gz" -o -name "$1.ko.xz" -o -name "$1.ko.zst" \) 2>/dev/null | head -n 1
}
builtin() { grep -Eq "(^|/)$1[.]ko$" "$module_dir/modules.builtin" 2>/dev/null; }
present() {
    [ -d "/sys/module/$1" ] || [ -n "$(module_file "$1")" ] ||
        builtin "$1"
}
load_module() {
    [ -d "/sys/module/$1" ] && return 0
    builtin "$1" && return 0
    modprobe "$1" 2>/dev/null && return 0
    # Older firmware can lack modprobe metadata. Never force-load a module.
    file=$(module_file "$1")
    case "$file" in *.ko) insmod "$file" 2>/dev/null ;; *) return 1 ;; esac
}

usb_driver_idle() (
    module=$1
    [ -d "/sys/bus/usb/drivers/$module" ] || exit 1
    for interface in "/sys/bus/usb/drivers/$module/"*:*; do
        [ ! -L "$interface" ] || exit 1
    done
    refs=$(cat "/sys/module/$module/refcnt" 2>/dev/null) || exit 1
    if [ "$module" = cdc_ether ] && [ -L /sys/module/cdc_ether/holders/rndis_host ]; then
        [ "$refs" = 1 ]
    else
        [ "$refs" = 0 ]
    fi
)

reload_rndis_pair() (
    # usbnet is shared by other adapters. Only replace the CDC/RNDIS pair.
    [ -n "$previous_pair" ] || exit 1
    cdc=$(module_file cdc_ether)
    rndis=$(module_file rndis_host)
    case "$cdc:$rndis" in *.ko:*.ko) ;; *) exit 1 ;; esac
    usb_driver_idle rndis_host && usb_driver_idle cdc_ether || exit 1
    rmmod rndis_host || exit 1
    if usb_driver_idle cdc_ether && rmmod cdc_ether; then
        if insmod "$cdc" && insmod "$rndis"; then exit 0; fi
        # Restore the former drivers if loading the new pair failed.
        if [ -d /sys/module/cdc_ether ] && usb_driver_idle cdc_ether; then
            rmmod cdc_ether
        fi
        [ -d /sys/module/cdc_ether ] || insmod "$previous_pair/cdc_ether.ko"
    fi
    insmod "$previous_pair/rndis_host.ko"
    exit 1
)

if ! opkg update; then
    report 'Driver feed update failed; existing USB drivers retained.'
    exit 1
fi
catalog=$(opkg list) || { report 'USB driver catalog unavailable.'; exit 1; }
previous_pair=""
if [ -d /sys/module/cdc_ether ] && [ -d /sys/module/rndis_host ]; then
    cdc=$(module_file cdc_ether)
    rndis=$(module_file rndis_host)
    case "$cdc:$rndis" in
        *.ko:*.ko)
            if previous_pair=$(mktemp -d /tmp/modgui-smartphone-drivers.XXXXXX); then
                if cp "$cdc" "$previous_pair/cdc_ether.ko" &&
                   cp "$rndis" "$previous_pair/rndis_host.ko"; then
                    trap 'rm -rf "$previous_pair"' EXIT
                else
                    rm -rf "$previous_pair"
                    previous_pair=""
                fi
            fi
            ;;
    esac
fi
failed=0
pair_updated=0
pair_reloaded=0
reboot_needed=0
missing=""
modules=""
boot_modules=""
# ECM/RNDIS and NCM cover common Android phones; EEM/subset are optional
# alternatives. opkg checks the firmware-specific kernel ABI and architecture.
for spec in kmod-usb-net:usbnet kmod-usb-net-cdc-ether:cdc_ether \
    kmod-usb-net-rndis:rndis_host kmod-usb-net-cdc-ncm:cdc_ncm \
    kmod-usb-net-cdc-eem:cdc_eem kmod-usb-net-cdc-subset:cdc_subset; do
    package=${spec%%:*}
    module=${spec#*:}
    # Built-in drivers cannot be replaced by installing a module. Otherwise
    # prefer the configured feed, retaining opkg's ABI and file ownership checks.
    if ! builtin "$module"; then
        if available "$package"; then
            was_installed=0
            installed "$package" && was_installed=1
            old_version=$(version "$package")
            if [ "$was_installed" = 1 ]; then
                opkg upgrade "$package"
            else
                opkg install "$package"
            fi
            result=$?
            new_version=$(version "$package")
            if [ -d "/sys/module/$module" ] &&
                { [ "$old_version" != "$new_version" ] ||
                  { [ "$was_installed" = 0 ] && installed "$package"; }; }; then
                case "$module" in
                    cdc_ether|rndis_host) pair_updated=1 ;;
                    *) reboot_needed=1 ;;
                esac
            fi
            [ "$result" = 0 ] || failed=1
        elif ! present "$module" && ! installed "$package"; then
            missing="$missing $package"
        fi
    fi
    if present "$module"; then
        modules="$modules $module"
        builtin "$module" || boot_modules="$boot_modules $module"
        load_module "$module" || failed=1
    elif installed "$package"; then
        # An installed package with no usable module needs attention too.
        failed=1
    fi
done

if [ "$pair_updated" = 1 ]; then
    if [ "$failed" = 0 ] && [ "$reboot_needed" = 0 ] && reload_rndis_pair; then
        pair_reloaded=1
    else
        reboot_needed=1
        if [ -n "$previous_pair" ] &&
           { [ ! -d /sys/module/cdc_ether ] || [ ! -d /sys/module/rndis_host ]; }; then
            failed=1
        fi
    fi
fi
[ "$reboot_needed" = 0 ] || touch "$reboot_file"

if [ -n "$modules" ]; then
    mkdir -p /etc/modules.d
    printf '%s\n' $boot_modules > "$boot_file"
fi
if [ "$failed" = 1 ]; then
    report 'Some USB drivers could not be installed or loaded; check the package feed and kernel compatibility.'
    exit 1
elif [ -z "$modules" ]; then
    report 'No USB network drivers available in the configured feeds.'
    exit 1
elif [ "$pair_reloaded" = 1 ] || [ -f "$reboot_file" ]; then
    message='USB driver packages updated from feeds.'
    if [ "$pair_reloaded" = 1 ]; then
        message="$message CDC Ethernet and RNDIS reloaded without restarting the router."
    fi
    [ -z "$missing" ] || message="$message Optional packages not supplied by the feeds:$missing"
    report "$message"
elif [ -n "$missing" ]; then
    report "Available USB drivers ready; optional packages not supplied by the feeds:$missing"
else
    report 'USB network drivers installed and loaded.'
fi
