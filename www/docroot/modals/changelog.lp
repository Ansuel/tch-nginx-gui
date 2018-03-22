--pretranslated: do not change this file

local ui_helper = require("web.ui_helper")

ngx.print(ui_helper.createHeader("Changelog", false, false)) 

ngx.print('\
<div class="modal-body no-save">\
  <fieldset>\
    <form class="form-horizontal" method="post" action="modals/changelog.lp">\
    ');
	  local html = {}
	  local basic = {
        span = {
          class = "span8",
		  style = "border-bottom: 1px solid #e5e5e5;padding-bottom: 10px"
        },
      }
      html[#html + 1] = '<legend>' .. T"Mainline 17.3 Cyan ( AGTEF_1.1.1_001 )" .. '</legend>'
	  html[#html + 1] = ui_helper.createLabel(T"6.7", "Reworkato voicemode e bridgemode, fixato problema telegestione non funzionante, aggiornate traduzioni", basic)
	  html[#html + 1] = ui_helper.createLabel(T"6.6", "Vari fix, si spera stabile sta volta", basic)
	  html[#html + 1] = ui_helper.createLabel(T"6.5", "Nuovo release channel dev, cpuload e altro in gui, quintacolonna (non il programma)", basic)
	  html[#html + 1] = ui_helper.createLabel(T"6.4", "Miglioramenti al sistema di aggiornamento gui", basic)
	  html[#html + 1] = ui_helper.createLabel(T"6.3", "Soppressione dei log eccessivi e fix funzione di esport", basic)
	  html[#html + 1] = ui_helper.createLabel(T"6.2", "Taaaaanto bugfix e reso il bottone controlla aggiornamenti funzionante", basic)
	  html[#html + 1] = ui_helper.createLabel(T"6.1", "Aggiunto blacklist tool agli installer", basic)
	  html[#html + 1] = ui_helper.createLabel(T"6.0", "Rebase con i nuovi cambiamenti", basic)
	  html[#html + 1] = '<legend>' .. T"Mainline 17.3 Cyan ( AGTEF_1.1.0 )" .. '</legend>'
	  html[#html + 1] = ui_helper.createLabel(T"5.11", "Iniziale supporto per luci,ariang e transmission", basic)
	  html[#html + 1] = ui_helper.createLabel(T"5.10", "Upnp fix thx  Jecht_Sin", basic)
	  html[#html + 1] = ui_helper.createLabel(T"5.9", "Test wifi fix, thx aezakmi123", basic)
	  html[#html + 1] = ui_helper.createLabel(T"5.8", "Latenza maggiorata fixata, (disabilitati risparmi energetici per le porte ed il traffico 5ghz", basic)
	  html[#html + 1] = ui_helper.createLabel(T"5.7", "Fixata finalmente tab assistenza e selettore porte. (questa volta per sempre...)", basic)
	  html[#html + 1] = ui_helper.createLabel(T"5.6", "Aggiunto uptime wan", basic)
	  html[#html + 1] = ui_helper.createLabel(T"5.5", "Fixato cpustep, thx @shdf", basic)
	  html[#html + 1] = ui_helper.createLabel(T"5.4", "Fixato selettore porta nella tab assist", basic)
	  html[#html + 1] = ui_helper.createLabel(T"5.3", "Aggiunto selettore driver xdsl", basic)
	  html[#html + 1] = ui_helper.createLabel(T"5.2", "ReRefix tab lan e fix css per primo root", basic)
	  html[#html + 1] = ui_helper.createLabel(T"5.1", "Refix tab lan e fix cwmpd (forse)", basic)
	  html[#html + 1] = ui_helper.createLabel(T"5.0", "Fix autocompletamento e tab lan", basic)
	  html[#html + 1] = '<legend>' .. T"Mainline 17.3 Cyan ( AGTEF_1.1.0_001 )" .. '</legend>'
	  html[#html + 1] = ui_helper.createLabel(T"4.6", "Fixato switch tab mobile", basic)
	  html[#html + 1] = ui_helper.createLabel(T"4.5", "Selettore skin gui nella tab Sistema Extra", basic)
	  html[#html + 1] = ui_helper.createLabel(T"4.4", "Fix pagina wireless", basic)
	  html[#html + 1] = ui_helper.createLabel(T"4.3", "Traduzioni aggiornate (thx @DarkNiko), altri fix telegestione e altro", basic)
	  html[#html + 1] = ui_helper.createLabel(T"4.2", "Altri fix, gui stabile", basic)
	  html[#html + 1] = ui_helper.createLabel(T"4.1", "Vari fix, telegestione fixata (forse? no...), gui stabile", basic)
	  html[#html + 1] = ui_helper.createLabel(T"4.0", "Rebase Completo", basic)
	  html[#html + 1] = '<legend>' .. T"Mainline 17.1 Aqua" .. '</legend>'
	  html[#html + 1] = ui_helper.createLabel(T"3.36", "Fix grafico 5Ghz", basic)
	  html[#html + 1] = ui_helper.createLabel(T"3.35", "Svecchiamento grafica pt.2", basic)
	  html[#html + 1] = ui_helper.createLabel(T"3.34", "Fix grafico lan", basic)
	  html[#html + 1] = ui_helper.createLabel(T"3.33", "Migliorata velocità gui", basic)
	  html[#html + 1] = ui_helper.createLabel(T"3.32", "Migliorata configurazione wizard voip (chiede anche il resto ora....)", basic)
	  html[#html + 1] = ui_helper.createLabel(T"3.31", "Aggiunte voci domain name e realm sezione voip", basic)
	  html[#html + 1] = ui_helper.createLabel(T"3.30", "Fix riattivazione dhcp e bridge mode", basic)
	  html[#html + 1] = ui_helper.createLabel(T"3.29", "Fix telegestione", basic)
	  html[#html + 1] = ui_helper.createLabel(T"3.28", "Testing accesso remoto con scelta di porta. (Necessario un reboot per cambiare la porta)", basic)
	  html[#html + 1] = ui_helper.createLabel(T"3.27", "Aggiornato nginx, attivato gzip compression aumentata reattività webui", basic)
	  html[#html + 1] = ui_helper.createLabel(T"3.26", "Fixed opkg update problem (openssl-util manuallty installed) and mac address", basic)
	  html[#html + 1] = ui_helper.createLabel(T"3.25", "Verde è più bello :)", basic)
	  html[#html + 1] = ui_helper.createLabel(T"3.24", "Fix vari, wizard fixato", basic)
	  html[#html + 1] = ui_helper.createLabel(T"3.23", "Aggiunto Traffic Monitor nella sezione dispositivi", basic)
	  html[#html + 1] = ui_helper.createLabel(T"3.22", "Fix vari", basic)
	  html[#html + 1] = ui_helper.createLabel(T"3.21", "Fix bug aggiornamento disponibile", basic)
	  html[#html + 1] = ui_helper.createLabel(T"3.20", "Aggiunto update gui offline e fix vari", basic)
	  html[#html + 1] = ui_helper.createLabel(T"3.19", "Nuovi pacchetti (kmod funzionanti), aggiornato opkg repo. Si ringrazia Roleo per la compilazione", basic)
	  html[#html + 1] = ui_helper.createLabel(T"3.18", "Introdotto nuovo daemon dlnad", basic)
	  html[#html + 1] = ui_helper.createLabel(T"3.17", "Fix sysupgrade (flash altra partizione ma niente switchover, ora flasha quella su cui è presente il firmware e non esegue switchover)", basic)
	  html[#html + 1] = ui_helper.createLabel(T"3.16", "Rimosso aggiornamento adsl e cwmpd... ", basic)
	  html[#html + 1] = ui_helper.createLabel(T"3.15", "Possibile fix tod wireless", basic)
	  html[#html + 1] = ui_helper.createLabel(T"3.14", "Fix card_limiter", basic)
	  html[#html + 1] = ui_helper.createLabel(T"3.13", "Fix per user non telecom", basic)
	  html[#html + 1] = ui_helper.createLabel(T"3.12", "Miglioramento script root e aggiunte alcune traduzioni", basic)
	  html[#html + 1] = ui_helper.createLabel(T"3.11", "Disabilitato daemon ipv6, per ora è comunque buggato e rotto", basic)
	  html[#html + 1] = ui_helper.createLabel(T"3.10", "Bottone Bridge Fixato @Pigr8. Opkg quasi funzionante, provare ad installare i pacchetti e segnalare quali funzionanti.", basic)
	  html[#html + 1] = ui_helper.createLabel(T"3.9", "Fixato telnet e pagina password", basic)
	  html[#html + 1] = ui_helper.createLabel(T"3.8", "Fixato problema aggiornamento convertito in reset... (causato da un mio errore per aver introdotto script nel posto sbagliato)", basic)
	  html[#html + 1] = ui_helper.createLabel(T"3.7", "Probabile fix al bug del dns", basic)
	  html[#html + 1] = ui_helper.createLabel(T"3.6", "Aggiunto switch per disattivare check bank_1 (Funzioni Avanzate)", basic)
	  html[#html + 1] = ui_helper.createLabel(T"3.5", "Fixato bug password", basic)
	  html[#html + 1] = ui_helper.createLabel(T"3.4", "Refactor platform.sh e script di root per l'upgrade della versione", basic)
	  html[#html + 1] = ui_helper.createLabel(T"3.3", "Aggiornato driver xDSL", basic)
	  html[#html + 1] = ui_helper.createLabel(T"3.2", "Tutti in bank_1, inserito check in boot per forzare tutti lì", basic)
	  html[#html + 1] = ui_helper.createLabel(T"3.1", "Tab DHCP fixata", basic)
	  html[#html + 1] = ui_helper.createLabel(T"3.0", "Merge cambiamenti da AGTEF_1.0.4_007", basic)
	  html[#html + 1] = '<legend>' .. T"Mainline 17.1 Aqua" .. '</legend>'
	  html[#html + 1] = ui_helper.createLabel(T"2.23", "Aggiunto bottone transfer to bank 1 nella tab system (Funzioni Avanzate) ", basic)
	  html[#html + 1] = ui_helper.createLabel(T"2.22", "Aggiunto bottone switchover e informazioni sui bank nella tab system", basic)
	  html[#html + 1] = ui_helper.createLabel(T"2.21", "Fixata casella DDNS non visualizzata", basic)
	  html[#html + 1] = ui_helper.createLabel(T"2.20", "Aggiunto sistema di autoaggiornamento gui e segnalazione nuova versione. (WIP)", basic)
	  html[#html + 1] = ui_helper.createLabel(T"2.19", "Fixato bug riavvio, fixata tab samba... per il printsharing è necessario abilitare samba.", basic)
	  html[#html + 1] = ui_helper.createLabel(T"2.18", "Aggiunto card limiter e fixato bug VOICEMODE (si prega di rieseguire la procedura)", basic)
	  html[#html + 1] = ui_helper.createLabel(T"2.17", "Aggiunta funzione per modalità asstenza permanente e scelta password", basic)
	  html[#html + 1] = ui_helper.createLabel(T"2.16", "Aggiunte funzioni per il reset TOTALE e il ripristino della gui originale", basic)
	  html[#html + 1] = ui_helper.createLabel(T"2.15", "Aggiunta visualizzazione codec voip e possibilità di configurarli", basic)
	  html[#html + 1] = ui_helper.createLabel(T"2.14", "Aggiunto WakeOnWan e fixata visualizzazione e funzione del portforward", basic)
	  html[#html + 1] = ui_helper.createLabel(T"2.13", "Piccola rivisitazione grafica, aggiunta icone e inseriti controlli SSH e Telnet in Funzioni Extra di Sistema", basic)
	  html[#html + 1] = ui_helper.createLabel(T"2.12", "Aggiunto Telnet e reso attivabile da gui (tab Funzioni Avanzate)", basic)
	  html[#html + 1] = ui_helper.createLabel(T"2.11", "Resi funzionali BridgeMode e VoiceMode", basic)
	  html[#html + 1] = ui_helper.createLabel(T"2.10", "Fixato invalid istance nel SetupWizard.", basic)
	  html[#html + 1] = ui_helper.createLabel(T"2.9", "Fixato il QOS.", basic)
	  html[#html + 1] = ui_helper.createLabel(T"2.8", "Altre traduzioni alla gui by DarkNiko.", basic)
	  html[#html + 1] = ui_helper.createLabel(T"2.7", "Fixato bug per il quale non era possibile creare regole di port forward.", basic)
	  html[#html + 1] = ui_helper.createLabel(T"2.6", "Vari fix e aggiornamenti alla traduzione della webui. Si ringrazia DarkNiko per l'ottimo lavoro.", basic)
	  html[#html + 1] = ui_helper.createLabel(T"2.5", "Fixate/Rimosse le Invalid Istance, aggiunta possibilità di modificare regole qos.", basic)
	  html[#html + 1] = ui_helper.createLabel(T"2.4", "Aggiunte impostazioni Hostname nella tab Gateway e Domain Name nella tab Rete Locale", basic)
	  html[#html + 1] = ui_helper.createLabel(T"2.3", "Sbloccate altre funzioni e perfezionato metodo di sblocco webui. VoiceMode e BridgeMode ancora WIP!", basic)
	  html[#html + 1] = ui_helper.createLabel(T"2.2", "Fixati alcuni bottoni e aggiunto bottone per controllare aggiornamenti", basic)
	  html[#html + 1] = ui_helper.createLabel(T"2.1", "Fix bug bypass password", basic)
	  html[#html + 1] = ui_helper.createLabel(T"2.0", "Merge WebUi firmware beta telecom", basic)
	  html[#html + 1] = '<legend>' .. T"Mainline 16.3 Aqua" .. '</legend>' 
	  html[#html + 1] = ui_helper.createLabel(T"1.12", "Aggiungi bottoni mobile e cwmp", basic)
	  html[#html + 1] = ui_helper.createLabel(T"1.11", "Aggiunge funzioni eco nella tab Gateway", basic)
	  html[#html + 1] = ui_helper.createLabel(T"1.10", "FIX IPV6 e aggiunto changelog", basic)
	  html[#html + 1] = ui_helper.createLabel(T"1.9", "Aggiunte funzioni Risparmio Energetico Configurabili (/etc/config/power)", basic)
	  html[#html + 1] = ui_helper.createLabel(T"1.8", "Aggiunta password Numero Voip nella visione generale della tab Telefono", basic)
	  html[#html + 1] = ui_helper.createLabel(T"1.7", "Aggiunta Voice Mode (WIP)", basic)
	  html[#html + 1] = ui_helper.createLabel(T"1.6", "Aggiunta Bridge Mode (WIP)", basic)
	  html[#html + 1] = ui_helper.createLabel(T"1.5", "Rimosso blocco degli spazzi nell'ssid", basic)
	  html[#html + 1] = ui_helper.createLabel(T"1.4", "Inserito conferma per inserimento di password non sicura. (Ora è possibile inserire password minore di 12 caratteri)", basic)
	  html[#html + 1] = ui_helper.createLabel(T"1.3", "Aggiunto Wizard (WIP)", basic)
	  html[#html + 1] = ui_helper.createLabel(T"1.2", "Aggiunte tab switch e QOS (WIP)", basic)
	  html[#html + 1] = ui_helper.createLabel(T"1.1", "Abilitate tab nascoste", basic)
	  html[#html + 1] = ui_helper.createLabel(T"1.0", "Rimosso css e logo tim", basic)
	
	ngx.print(html)
	
ngx.print('\
    </form>\
  </fieldset>\
</div>\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
'); 
