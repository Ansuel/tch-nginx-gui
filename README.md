<h3><strong>This is a modified and universal version of the GUI installed on Technicolor Modem/Router compatibile with (and probably not only):</strong></h3>
  <ul>
  <li>TG789vAC v2</li>
  <li>TG800</li>
  <li>TG799</li>
  <li>DGA4130</li>
  <li>DGA4132</li>
  </ul>
with many fix and new feature like:
<ul>
<li>DLNA Fully working.</li>
<li>Show VoIP Password directly on the GUI.</li>
<li>Upgrade/Downgrade firmware from the GUI.</li>
<li>Setting two channel for the update (DEV or Stable).</li>
<li>Eco settings for the CPU and LEDs.</li>
<li>Easy setting up Bridge or Voice Mode.</li>
<li>Traffic monitoring with Charts.</li>
<li>Fast Cache Options.</li>
<li>Select many xDSL drivers compatible.</li>
<li>Free to install LuCi GUI or sharing service.</li>
<li>Spoofing firmware version to bypass CWMP controls.</li>
<li>Select many skins for the GUI, like Fritz!Box one.</li>
<li>And many other...</li>
</ul>
<p><strong>You can help the development of this GUI by opening issue to report issue or improvements.</strong><br /><strong>All the infos can be found here and on the relative forum.</strong></p>
<p>(To write on this forum you need to write in the presentation section after the first login)<br />https://www.ilpuntotecnico.com/sblocco-smart-modem-evolution-dga4130-agtef/<br />https://www.ilpuntotecnico.com/forum/index.php/topic,78162.0.html<br />
  https://www.ilpuntotecnico.com/forum/index.php?topic=77325</p>
<p>&nbsp;</p>

<h2><strong>Simplest install instructions for Stable release:</strong></h2>

<h3><strong>first get root acces to your Gateway</strong></h3>
Some Topics to help you get root:
<ul>
<li>DGA4130 TIM: https://www.ilpuntotecnico.com/forum/index.php/topic,77325.html</li>
<li>DGA4132 TIM: https://www.ilpuntotecnico.com/forum/index.php/topic,78162.html</li>
<li>789vAC v2 TIM: https://www.ilpuntotecnico.com/forum/index.php/topic,77071.html</li>
<li>789vAC v2 Tiscali: https://www.ilpuntotecnico.com/forum/index.php/topic,77988.html</li>
</ul>
General GUI Topic: https://www.ilpuntotecnico.com/forum/index.php/topic,78585.0.html

<h3>Than execute these shell commands:</h3><br />
<strong>wget -P /tmp http://repository.ilpuntotecnico.com/files/Ansuel/AGTEF/GUI.tar.bz2<br />
bzcat /tmp/GUI.tar.bz2 | tar -C / -xvf -<br />
/etc/init.d/rootdevice force<br /><br /></strong>

if you get some error with the wget command just manually download the GUI.tar.bz2 file and put in /tmp folder via SCP than execute the other  commands

How it looks:
<img src="https://i.imgur.com/ZcSANgW.png">
