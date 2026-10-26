#! /bin/sh
# Copyright (c) 2016 Technicolor
isEnabled=`uci get mmpbx.voipdiagnostics.enabled`
currState=`uci get mmpbx.voipdiagnostics.action`
filePath=`uci get mmpbx.voipdiagnostics.path`
fileName=`uci get mmpbx.voipdiagnostics.filename`
if [[ ! -z "$fileName" ]] && [[ ! -z "$filePath" ]] && [[ "$filePath" != "uci: Entry not found" ]] && [[ "$fileName" != "uci: Entry not found" ]];
then
	logfile=$filePath/$fileName
elif [[ ! -z "$fileName" ]] && [[ "$filePath" != "uci: Entry not found" ]];
then
	logfile="/tmp/$fileName"

elif [[ ! -z "$filePath" ]] && [[ "$fileName" != "uci: Entry not found" ]];
then
	logfile="$filePath/voip_diagnostics.txt"
else
	logfile="/tmp/voip_diagnostics.txt"
fi
if [ $currState == "idle" ];
then
	if [ -f $logfile ];
	then
	rm $logfile
	fi
	exit
fi

if [[ $isEnabled == 1 ]] && [[ $currState == "request" ]];
then
	uci set mmpbx.voipdiagnostics.action="processing"
	uci commit mmpbx
	maskedUri=\"+NUM\"
	TAB=$'\t'
	rootPath=`grep -F '^InternetGatewayDevice%.' /etc/config/transformer`
	if [ -n "$rootPath" ];
	then
		root="Device"
	else
		root="InternetGatewayDevice"
	fi
	if [ -f /tmp/mmpbx_dump ]; then
		cp /tmp/mmpbx_dump $logfile
	fi

	echo -e "\n=========================== PROFILE BASED SERVICE DETAILS =============================== \n" >> $logfile
	TMPFILE=`mktemp -t diagnostics_dataXXXXXXX` && {
		TMPFILE2=`mktemp -t diagnostics_dataXXXXXXX` && {
			TMPURI=`mktemp -t uri_XXXXXXX` && {
			awk '/(option uri )|(config profile)/{print $NF}' /etc/config/mmpbxrvsipnet | sed "s/'//g" >> $TMPURI
			echo "$(transformer-cli get $root.Services.VoiceService.1.VoiceProfile.1.Line.)" > $TMPFILE
			while read line1
			do
				read line2
				path=$(grep "$line2" $TMPFILE | grep "SIP.URI" | cut -d . -f 1-8)
				echo "$(transformer-cli get $path\.CallingFeatures\.)" > $TMPFILE2
				echo -e "\n$line1" | tr 'a-z' 'A-Z' >> $logfile
				echo -e "\n" >> $logfile
				cut -d . -f10 $TMPFILE2  | sed 's/\[.*\]//' | sed -e "s/$line2/$maskedUri/g" | sed "s/Number.*/Number = $maskedUri/" >> $logfile
			done < $TMPURI
			}
		}
	}
	rm $TMPFILE $TMPFILE2 $TMPURI
	echo -e "\n======================== SIP UA DETAILS =====================================      \n" >> $logfile
	for i in `awk '/config profile/{print $NF}' /etc/config/mmpbxrvsipnet`;
	do
		profileStatus=$(ubus call mmpbx.profile get "{'profile':$i}")
		if [[ -z "$profileStatus" ]];
		then
                    echo -e "Unable to fetch details as voice daemon may not be running \n" >> $logfile
			break
		fi
		echo "$profileStatus" | sed -e "/"uri"/c\\$TAB\\$TAB\"uri\" : $maskedUri" >> $logfile
	done

	echo -e "========================= LINE STATE DETAILS ====================================       \n" >> $logfile

	for i in `awk '/config device/{print $NF}' /etc/config/mmpbxbrcmfxsdev`;
	do
		lineStatus=$(ubus call mmpbxbrcmfxs.state get "{'device':$i}")
		if [[ -z "$lineStatus" ]];
		then
			echo -e "Unable to fetch details as voice daemon may not be running \n" >> $logfile
			break
		fi
		echo "$lineStatus" | sed 's/fxs_dev_/Line /g' >> $logfile
	done


	callStatus=$(ubus call mmpbx.call get)
	if [[ -z "$callStatus" ]];
	then
		echo -e "Unable to fetch details as voice daemon may not be running \n" >> $logfile
	fi
	if [ $(echo "$callStatus" | grep "call" | wc -l) -ne 0 ]
	then
		echo -e "=================== CALL STATE  DETAILS ====================================       \n" >> $logfile
		echo "$callStatus" | sed -e "/"directoryNumber"/c\\$TAB\\$TAB\"directoryNumber\" : $maskedUri" -e "/"partyDisplayName"/c\\$TAB\\$TAB\"partyDisplayName\" : $maskedUri" -e "/"party"/c\\$TAB\\$TAB\"party\" : $maskedUri">> $logfile

		for i in `awk '/config profile/{print $NF}' /etc/config/mmpbxrvsipnet`;
		do
			profileCallID=$(ubus call mmpbxrvsipnet.profile.call get "{'profile':$i}")
			if [[ -z "$profileCallID" ]];
			then
	                        echo -e "Unable to fetch details as voice daemon may not be running \n" >> $logfile
	                        break
                        fi
			if [[ !"${profileCallID/call-Id}"="$profileCallID" ]];
			then
			echo "$profileCallID" >> $logfile
			fi
		done

		echo  -e "=================== RTP DETAILS OF ONGOING CALL ====================================       \n" >> $logfile
		rtpStats=$(ubus call mmpbx.rtp.session list '{ "rtcp" : "1"}')
		if [[ -z "$rtpStats" ]];
		then
			echo -e "Unable to fetch details as voice daemon may not be running \n" >> $logfile
		else
			echo "$rtpStats" | sed -e "/"LineName"/c\\$TAB\\$TAB\"LineName\" : $maskedUri" >> $logfile
		fi
	else
		echo "No Ongoing Calls" >> $logfile
	fi

	uci set mmpbx.voipdiagnostics.action="completed"
	uci commit mmpbx
else
	echo -e "voip diagnostics not enabled\n"
	uci set mmpbx.voipdiagnostics.action="failed"
	uci commit mmpbx
fi
