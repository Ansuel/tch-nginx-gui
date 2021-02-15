[![Donate](https://img.shields.io/badge/Donate-PayPal-green.svg)](https://www.paypal.me/AnsuelS) [![License](https://img.shields.io/github/license/Ansuel/tch-nginx-gui.svg?style=flat)](https://github.com/Ansuel/tch-nginx-gui/blob/master/LICENSE) [![Lastest Build](https://img.shields.io/circleci/project/github/Ansuel/tch-nginx-gui.svg?style=flat)](https://circleci.com/gh/Ansuel/tch-nginx-gui/tree/master) [![Lastest Release](https://img.shields.io/github/release/Ansuel/tch-nginx-gui/all.svg?style=flat&label=DEV%20version)](https://github.com/Ansuel/tch-nginx-gui/releases) [![Stable Release](https://img.shields.io/github/release/Ansuel/tch-nginx-gui.svg?style=flat&label=STABLE%20version)](https://github.com/Ansuel/tch-nginx-gui/releases)

<h3><strong>This is a highly modified and universal version of the GUI installed on all Technicolor Modem/Routers compatibile with (and probably not only):</strong></h3>
  <ul>
  <li>DGA4132 / VBNT-S</li>
  <li>DGA4131 / VBNT-O</li>
  <li>DGA4130 / VBNT-K</li>
  <li>TG589vac / VANT-E</li>
  <li>TG788vn v2 / VDNT-W</li>
  <li>TG789vac v2 HP / VBNT-L</li>
  <li>TG789vac v2 / VANT-6</li>
  <li>TG789vac (v1) / VANT-D</li>
  <li>TG789vac XTREAM 35B / VBNT-F</li>
  <li>TG799vac / VANT-F</li>
  <li>TG799vac XTREAM / VBNT-H</li>
  <li>TG800vac / VANT-Y</li>
  </ul>
with many fixes and new features like:
<ul>
<li><b>Quick glance statistics page</b></li>
<li>DLNA Fully working</li>
<li>Visualise CPU load</li>
<li>Show VoIP Password directly on the GUI</li>
<li>Upgrade/Downgrade firmware from the GUI</li>
<li>Export and Save modem configuration from the GUI</li>
<li>Ability to select two channels for the update (DEV or Stable)</li>
<li>Eco settings for the CPU and LEDs</li>
<li>Easy set up for Bridge or Voice Mode</li>
<li>Ability to revert from brige/voice to normal without factory reset</li>
<li>Traffic monitoring with Interactive Charts</li>
<li>Fast Cache Options</li>
<li>DoS Protect Options</li>
<li>Improved Traffic Graph</li>
<li>Dosens of xDSL Stats</li>
<li>Ability to Select many compatable xDSL drivers</li>
<li>Ability to install LuCI GUI or sharing service like transmission</li>
<li>Spoofing of firmware version to bypass CWMP controls</li>
<li>Select many skins for the GUI, like the Fritz!Box one</li>
<li>Install extensions like: Telstra Basic GUI, LuCI, Transmission, Aria2</li>
<li>And many others...</li>
</ul>
<p><strong>You can help the development of this GUI by reporting issues or suggesting improvements.</strong><br /><strong>All the infomation can be found here and on the ilpuntotecnico forum (https://www.ilpuntotecnico.com/forum) (To write on this forum you need to write in the presentation section after the first login).</strong></p>

<h2><strong>Basic installation instructions for the latest Stable release:</strong></h2>

<h3><strong>First you need to get root access to your Gateway</strong></h3>
Some Topics to help you get root access:
<ul>
<li>DGA4130 TIM: https://www.ilpuntotecnico.com/forum/index.php/topic,77325.html</li>
<li>DGA4132 TIM: https://www.ilpuntotecnico.com/forum/index.php/topic,78162.html</li>
<li>789vac v2 TIM: https://www.ilpuntotecnico.com/forum/index.php/topic,77981.0.html</li>
<li>789vac v2 Tiscali: https://www.ilpuntotecnico.com/forum/index.php/topic,77988.html</li>
<li>789vac v1/2/3, 799vac, 800vac and 797n v3 Any ISP: https://hack-technicolor.rtfd.io</li>
</ul>
General GUI Topic: https://www.ilpuntotecnico.com/forum/index.php/topic,81461.0.html

<h3>Then execute these commands (Active WAN/Internet connection required):</h3>

```
curl -k https://raw.githubusercontent.com/Ansuel/gui-dev-build-auto/master/GUI.tar.bz2 --output /tmp/GUI.tar.bz2
bzcat /tmp/GUI.tar.bz2 | tar -C / -xvf -
/etc/init.d/rootdevice force
```

You can find all of the autobuilt GUI versions at this link: https://github.com/Ansuel/gui-dev-build-auto

If you get an error during the download process or you have no Internet/WAN connection on the device, just manually download the GUI.tar.bz2 file and put in /tmp folder via SCP then execute the other (non curl) commands listed above.

If you find a bug, please report it using GitHub's Issue feature making sure you attach a photo and the log (Run: logread).
If you upload config files, please remove your personal details including your public IP and MAC.
In the future there will be a button/command in the GUI to generate a debug file.

Stats:
<img src="https://i.ibb.co/XjhF629/modemstats.jpg">

Cards:
<img src="https://i.ibb.co/5BDrRnx/odemcards.jpg">

<h2><strong>Donation</strong></h2>

If you want to donate to the developer of this modified gui use the button below

[![paypal](https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif)](https://www.paypal.me/AnsuelS)
