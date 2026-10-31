#!/bin/sh
# Use each firmware's configured feeds and normal opkg compatibility checks.
# Shared USB network dependencies are retained when the app is removed.
status_file=/etc/modgui-smartphone-drivers.status
boot_file=/etc/modules.d/60-modgui-smartphone-net
module_dir=/lib/modules/$(uname -r)

report() {
    printf '%s\n' "$1" > "$status_file"
    printf '%s\n' "$1"
}
installed() { opkg status "$1" 2>/dev/null | grep -q '^Status: .* installed$'; }
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

if ! opkg update; then
    report 'Driver feed update failed; existing USB drivers retained.'
    exit 1
fi
catalog=$(opkg list) || { report 'USB driver catalog unavailable.'; exit 1; }
failed=0
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
    # Reuse firmware, built-in and independently installed modules. In
    # particular, do not overwrite manual/vendor drivers with standard ones.
    if ! present "$module" && ! installed "$package"; then
        if available "$package"; then
            opkg install "$package" || failed=1
        else
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
elif [ -n "$missing" ]; then
    report "Available USB drivers ready; optional packages not supplied by the feeds:$missing"
else
    report 'USB network drivers installed and loaded.'
fi
