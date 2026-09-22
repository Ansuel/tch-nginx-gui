#!/bin/sh

[ -x /etc/init.d/pbx-asterisk ] || exit 0

/etc/init.d/pbx-asterisk restart || exit 1

# luci-app-pbx regenerates extensions.conf from scratch. Re-apply the
# documented Voipblock hooks when the AGI is installed, otherwise saving an
# unrelated PBX setting silently disables call filtering.
voipblock_agi=/usr/share/asterisk/agi-bin/voipblock
extensions_conf=/etc/asterisk/extensions_incoming.conf

if [ "$(uci -q get modgui.app.voipblock_for_asterisk)" = "1" ] && \
   [ -e "$voipblock_agi" ] && [ -f "$extensions_conf" ] && \
   ! grep -q 'ASTERISK_MANAGER_VOIPBLOCK' "$extensions_conf"; then
  extensions_tmp="/tmp/extensions.conf.voipblock.$$"

  if awk '
    /^exten => s,n\(doneblacklist\),NoOp\(\)$/ {
      anchor++
      print
      print "; ASTERISK_MANAGER_VOIPBLOCK"
      print "same => n,Set(__number=${CALLERID(num)})"
      print "same => n,AGI(voipblock,${number})"
      print "same => n,GotoIf($[\"${SPAM}\" = \"1\"]?voipblock-spam:voipblock-ok)"
      print "same => n(voipblock-spam),Hangup()"
      print "same => n(voipblock-ok),NoOp()"
      next
    }
    /Dial\(/ && /,r\)/ {
      sub(/,r\)/, ",rb(Voipblock^callee_handler^1))")
      dial_hooks++
    }
    /Dial\(/ { dials++ }
    { print }
    END {
      if (anchor != 1 || (dials > 0 && dial_hooks == 0)) exit 2
      print ""
      print "; ASTERISK_MANAGER_VOIPBLOCK"
      print "[Voipblock]"
      print "exten => callee_handler,1,NoOp()"
      print "same => n,Set(__DYNAMIC_FEATURES=Voipblock)"
      print "same => n,Return()"
      print ""
      print "[macro-Voipblock]"
      print "exten => s,1,AGI(voipblock,${number},spam)"
      print "same => n,GotoIf($[\"${SUCCESS}\" = \"1\"]?success:failed)"
      print "same => n(success),Playback(privacy-blacklisted)"
      print "same => n,Hangup()"
      print "same => n(failed),Playback(an-error-has-occurred)"
      print "same => n,Hangup()"
      print "same => n,MacroExit()"
    }
  ' "$extensions_conf" > "$extensions_tmp"; then
    chmod 644 "$extensions_tmp"
    mv "$extensions_tmp" "$extensions_conf"
  else
    rm -f "$extensions_tmp"
    logger -t asterisk-manager 'Voipblock hooks not applied: generated dialplan format changed'
    echo 'Warning: Voipblock hooks not applied: generated dialplan format changed' >&2
  fi
fi

if [ -x /etc/init.d/asterisk ]; then
  /etc/init.d/asterisk restart
fi
