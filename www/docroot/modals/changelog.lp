<%
-- Enable localization
gettext.textdomain('webui-core')

local lp = require("web.lp")
local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local content_helper = require("web.content_helper")

%>

<% ngx.print(ui_helper.createHeader("Changelog", false, false)) %>
<div class="modal-body update">
<%
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
%>
<fieldset>
	<legend><%= T"Mainline 17.1 Gold" %></legend>
    <form class="form-horizontal" method="post" action="modals/changelog.lp">
    <%
	  local basic = {
        span = {
          class = "span8",
		  style = "border-bottom: 1px solid #e5e5e5;padding-bottom: 10px"
        },
      }
      local html = {}
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
	ngx.print(html)
    %>
    </form>
  </fieldset>
	<legend><%= T"Mainline 17.1 Gold" %></legend>
    <form class="form-horizontal" method="post" action="modals/changelog.lp">
    <%
	  local basic = {
        span = {
          class = "span8",
		  style = "border-bottom: 1px solid #e5e5e5;padding-bottom: 10px"
        },
      }
      local html = {}
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
    %>
    </form>
  </fieldset>
</div>
<% ngx.print(ui_helper.createFooter()) %>
