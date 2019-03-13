<h2><strong>Basic installation instructions for the latest Stable release:</strong></h2>

<h3><strong>First you need to get root acces to your Gateway</strong></h3>

Some Topics to help you get root access:
<ul>
<li>DGA4130 TIM: https://www.ilpuntotecnico.com/forum/index.php/topic,77325.html</li>
<li>DGA4132 TIM: https://www.ilpuntotecnico.com/forum/index.php/topic,78162.html</li>
<li>789vac v2 TIM: https://www.ilpuntotecnico.com/forum/index.php/topic,77071.html</li>
<li>789vac v2 Tiscali: https://www.ilpuntotecnico.com/forum/index.php/topic,77988.html</li>
<li>799vac, 800vac and 797n v3 Any ISP: https://whirlpool.net.au/wiki/hack_technicolor</li>
</ul>
General GUI Topic: https://www.ilpuntotecnico.com/forum/index.php/topic,78585.0.html

<h3>Second execute these commands (Active WAN/Internet connection required):</h3>
```
curl -k https://raw.githubusercontent.com/Ansuel/gui-dev-build-auto/master/GUI.tar.bz2 --output /tmp/GUI.tar.bz2
```

<h3>Third execute these commands (Inactive connection required):</h3>
```
bzcat /tmp/GUI.tar.bz2 | tar -C / -xvf -
/etc/init.d/rootdevice force
```

Wait WITHOUT TURNING OFF, even if error or freeze, until the word Success!

Everything is AWESOME!!
