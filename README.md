<h3><strong>This is a highly modified and universal version of the GUI installed on all Technicolor Modem/Routers compatibile with (and probably not only):</strong></h3>
  <ul>
  <li>DGA4132</li>
  <li>DGA4130</li>
  <li>TG789vac v2</li>
  <li>TG800vac</li>
  <li>TG799vac</li>
  </ul>
with many fixes and new features like:
<ul>
<li>DLNA Fully working.</li>
<li>Visualise CPU load.</li>
<li>Show VoIP Password directly on the GUI.</li>
<li>Upgrade/Downgrade firmware from the GUI.</li>
<li>Export and Save modem configuration from the GUI.</li>
<li>Ability to select two channels for the update (DEV or Stable).</li>
<li>Eco settings for the CPU and LEDs.</li>
<li>Easy set up for Bridge or Voice Mode.</li>
<li>Traffic monitoring with Interactive Charts.</li>
<li>Fast Cache Options.</li>
<li>Ability to Select many compatable xDSL drivers.</li>
<li>Ability to install LuCI GUI or sharing service like transmission.</li>
<li>Spoofing of firmware version to bypass CWMP controls.</li>
<li>Select many skins for the GUI, like the Fritz!Box one.</li>
<li>And many others...</li>
</ul>
<p><strong>You can help the development of this GUI by opening issue to report issue or improvements.</strong><br /><strong>All the infomation can be found here and on the ilpuntotecnico forum (https://www.ilpuntotecnico.com/forum) (To write on this forum you need to write in the presentation section after the first login).</strong></p>

<h2><strong>Basic installation instructions for the latest Stable release:</strong></h2>

<h3><strong>First you need to get root acces to your Gateway</strong></h3>
Some Topics to help you get root access:
<ul>
<li>DGA4130 TIM: https://www.ilpuntotecnico.com/forum/index.php/topic,77325.html</li>
<li>DGA4132 TIM: https://www.ilpuntotecnico.com/forum/index.php/topic,78162.html</li>
<li>789vac v2 TIM: https://www.ilpuntotecnico.com/forum/index.php/topic,77071.html</li>
<li>789vac v2 Tiscali: https://www.ilpuntotecnico.com/forum/index.php/topic,77988.html</li>
<li>799vac, 800vac and 797n v3 Any ISP: https://www.crc.id.au/hacking-the-technicolor-tg799vac-and-unlocking-features/
</ul>
General GUI Topic: https://www.ilpuntotecnico.com/forum/index.php/topic,78585.0.html

<h3>Then execute these commands:</h3><br />
<strong>wget -P /tmp http://repository.ilpuntotecnico.com/files/Ansuel/AGTEF/GUI.tar.bz2<br />
bzcat /tmp/GUI.tar.bz2 | tar -C / -xvf -<br />
/etc/init.d/rootdevice force<br /><br /></strong>

If you get an error while running the wget command just manually download the GUI.tar.bz2 file and put in /tmp folder via SCP then execute the other (non wget) commands listed above.

Preview:
<img src="https://i.imgur.com/ZcSANgW.png">

<b>LUCI GUI not yet supported on the TG799, 800 and 797n v3</b>
<p>(A builroot system is need to compile necessary package to make luci works, rpcd and uhttpd)
