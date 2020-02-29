
---------------------------------------------------------------------------
# Mainline 18.3 Cobalt

9.5
---------------------------------------------------------------------------
 - Risolti alcuni problemi di compatibilità con internet explorer
 - Fix vari per ripristinare il funzionamentpo di modem 3G/LTE USB
 - Fix funzioni di copia e trasferimento bank
 - Aggiunta modal gestione cron
 - Aggiunta modal gestione init
 - Aggiunti ulteriori driver xDSL
 - Aggiunta possibilità di selezionare l'interfaccia per i servizi VoIP
 - Aggiunte app per TG789 Xtream 35B

9.4
---------------------------------------------------------------------------
- Aggiunta opzione per forzare interfaccia in HTTPS
- Aggiunta opzione per eseguire backup OpenWRT
- Aggiunta opzione per visualizzare access-concentrator per sessioni PPP
- Fixati alcuni errori sulla visualizzazione dell'IPv6
- Molti miglioramenti e fix grafici alle skin Unified e Fritz
- Sistemato reset config
- Aggiunta possibilità di resettare CWMP per forzare provisioning
- Aggiunto supporto a DJA0231 (Telstra)
- Sistemata impostazione WiFi NSC (Eco Modal)
- Migliorato supporto per DGA4131FWB, DJA0231, TG788, TG789 Xtream 35 Fastweb
- Importante fix che poteva causare bootloop se non venivano mai fatti aggiornamenti stabili
- I driver xDSL prima di essere impostati vengono preventivamente controllati per evitare bootloop
- Lo stato di alcuni processi (Aggiornamento GUI, cambio driver, installazione APP...) viene mostrato da GUI
- Aggiunta flag per attivare IPv6 su WAN
- Aggiunta pulsante per forzare provisioning CWMP
- Importanti fix per evitare comportamenti inaspettati durante gli upgrade firmware

9.3
---------------------------------------------------------------------------
- Ri-Aggiunto supporto alle app per i nuovi firmware
- Nuova skin unificata
- Inserita gestione led su DGA4131FWB
- Aggiunta possibilità di impostare potenza e country region radio WiFi
- Aggiunta funzione di riavvio programmato
- Possibilità di impostare server DNS per tutte le interfaccie (IP Extras)
- Sistemato wizard e vari errori su TG788
- Possibilità di impostare vendorid per il tipo di connessione wan DHCP (necessità Fastweb)
- Molti altri miglioramenti e bugfix minori

9.2
---------------------------------------------------------------------------
- Rebase su nuovi firmware 2.1.0 (Kernel linux aggiornato a 4.1.38)
- Vari rework agli script per una esecuzione più efficente
- Vari fix ai bug presenti nelle versioni precedenti
- E' ora possibile dare priorità ad un dispositivo specifico rispetto a tutta la rete (Tab Gestione spositivi)
- Aggiunte nuove funzioni di aggiornamento e possibilità di selezionare l'ISP manualmente
- Altri miglioramenti che sinceramente non ricordo

---------------------------------------------------------------------------
# Mainline 17.3 Cyan

9.1
---------------------------------------------------------------------------
- Aggiunto grafico utilizzo CPU e Memoria
- Aggiunta opzione per ripristinare configurazioni senza perdere GUI
- Stato telefonia in visualizzazione statistiche ora mostra errori di registrazione
- Stato telefonia mostra il numero collegato durante una chiamata
- Riorganizzata modal Servizi WAN" 

9.0
---------------------------------------------------------------------------
- Riorganizzata disposizione card
- Aggiunte ulteriori impostazioni di maschera versione
- Aggiunti vari driver xDSL
- Introdotto salvataggio delle conf dopo upgrade del firmware
- Introdotto ripristino di emergenza automatico in caso di rilevazione flash piena
- Forzata abilitazione porta console
- Aggiunto supporto a modem DGA4131 e TG789VAC XTREAM 35B
- Migliorato check aggiornamenti
- Rebase su firmware 2.0.1_001
- Fixato aggiornamento remoto da telegestione
- Migliorato sistema di aggiornamento
- Aggiornate traduzioni/stringhe inglesi italiane e tedesche
- Vari fix e miglioramenti

8.11
---------------------------------------------------------------------------
- Migliorate traduzioni
- Miglioramenti modalità bridge e modalità connessione
- Fixato visualizzazione UPnP su TG789
- Aggiunta possibilità di usare cups come gestore stampante
- Aggiunto applicazione aMule su TG789" 

8.10
---------------------------------------------------------------------------
- Aggiunte e fix per la gestione di ECO LED
- Miglioramenti Trauduzioni
- Miglioramenti di compatibilita' con l'interfaccia Telstra
- Fix problemi vari con la configurazione account SIP
- Aggiunta visualizzazione profilo VDSL
- Migliorato script aggiornamento GUI e tanti altri miglioramenti e bugfix

8.8
---------------------------------------------------------------------------
- Reworkata pagina iniziale gateway con caricamento dinamico ed introduzione della pagina statistiche.
- Nuova skin dark red. Introdotta possibilità di settare WifiTod per i wifi separatamente e per i wifi guest.
- Varie migliorie ai temi per desktop e mobile.
- Aggiunta Telstra gui alle applicazioni. Fixato support dei pacchetti per firmware 1.2.0. Vari fix e miglioramenti all'interfaccia.

8.7
---------------------------------------------------------------------------
- Fix download driver xdsl, fix assistance, ora vengono mostrate le password dei 3 profili disponibili.
- WIP supporto grafici per ADSL. Aggiunta tab per settare DosProtect

8.6
---------------------------------------------------------------------------
- Rework icone, aggiornata libreria fontawesome, fix e migliorie varie, 
- TEST sfp->stptag per sbloccare classe di ip 192.168.2.1... si attendono feedback per gli utenti che usano modulo sfp 

8.5
---------------------------------------------------------------------------
- Traduzioni aggiornate, fixato ddns

8.4
---------------------------------------------------------------------------
- Fix sysupgrade e dlna

8.3
---------------------------------------------------------------------------
- Migliorato e fixata visualizzazione del monitor traffico nella tab Dispositivi Connessi.

8.2
---------------------------------------------------------------------------
- Supporto per nuovo firmware beta.

8.1
---------------------------------------------------------------------------
- Fix e migliorie al cambio ip nella tab LAN, fix bug reset ppp dopo cambio ip modem.

8.0
---------------------------------------------------------------------------
- Aggiunto supporto per TG789vac (firmware Tiscali)
- fix cambio password, fix minori agli script, aggiunta pagina per Flow Cache.

7.17
---------------------------------------------------------------------------
- Aggiornate librerie web Aos.js e Jquery. Fix regole cron

7.16
---------------------------------------------------------------------------
- Aggiornate traduzioni.

7.15
---------------------------------------------------------------------------
- Aggiornamento nuovo server fix HLog, QLN , fix bug minori

7.14
---------------------------------------------------------------------------
- Fix errata visualizzazione Hlog e QLN

7.13
---------------------------------------------------------------------------
- Aggiunta visualizzazione della versione firmware del dslam

7.12
---------------------------------------------------------------------------
- Aggiunta tab per la gestione dei bridge.

7.11
---------------------------------------------------------------------------
- Aggiornamento traduzioni. Thx DarkNiko

7.10
---------------------------------------------------------------------------
- Bugfix vari, andare su github per controllare.

7.9
---------------------------------------------------------------------------
- Aggiunta possibilità di disattivare sra e bitswap, ditemi se devo aggiungerne altre...

7.8
---------------------------------------------------------------------------
- Aggiunta skin Fritz e bug fix minori

7.7
---------------------------------------------------------------------------
- Aggiungo Version Spoof nella tab sistema avanzato. 
- Segnala una versione falsa alla telegestione per permettere la sincronizzazione dei dati.

7.6
---------------------------------------------------------------------------
- Fix wansensing e bug dns

7.5
---------------------------------------------------------------------------
- Fix ethernet modal e fix iniziale wake on wan

7.4
---------------------------------------------------------------------------
- Bottone Eco Led ora funzionante! Fix vari, crediti, abilitato login https e fix assistance

7.3
---------------------------------------------------------------------------
- Aggiunto bottone per installare una blacklist vuota

7.2
---------------------------------------------------------------------------
- Aggiunto luci, supporto iniziale, wifi rotto.

7.1
---------------------------------------------------------------------------
- Aggiunta pagina mwan, se qualcuno sa a che serve spiegatemi...

7.0
---------------------------------------------------------------------------
- Rebase sul nuovo firmware

6.13
---------------------------------------------------------------------------
- Aggiunta traduzione tedesca Thx meyergru

6.12
---------------------------------------------------------------------------
- Introdotta autorimozione del bit antidowngrade AGTHP

6.11
---------------------------------------------------------------------------
- Fixato upgrade

6.10
---------------------------------------------------------------------------
- Aggiunta xupnp (solo per agtef 1.1.0 e superiori)

6.10
---------------------------------------------------------------------------
- Aggiunti grafici xDSL

6.9
---------------------------------------------------------------------------
- Aggiunto bottone WAN-MODE (WIP)

6.8
---------------------------------------------------------------------------
- Aggiunto gestore led (WIP)

6.7
---------------------------------------------------------------------------
- Reworkato voicemode e bridgemode, fixato problema telegestione non funzionante, aggiornate traduzioni
- aggiunto bottone per convertire porta WAN e opzioni per switchare modalità di connessione",basic)

6.6
---------------------------------------------------------------------------
- Vari fix, si spera stabile sta volta

6.5
---------------------------------------------------------------------------
- Nuovo release channel dev, cpuload e altro in gui, quintacolonna (non il programma)

6.4
---------------------------------------------------------------------------
- Miglioramenti al sistema di aggiornamento gui

6.3
---------------------------------------------------------------------------
- Soppressione dei log eccessivi e fix funzione di esport

6.2
---------------------------------------------------------------------------
- Taaaaanto bugfix e reso il bottone controlla aggiornamenti funzionante

6.1
---------------------------------------------------------------------------
- Aggiunto blacklist tool agli installer

6.0
---------------------------------------------------------------------------
- Rebase con i nuovi cambiamenti

5.11
---------------------------------------------------------------------------
- Iniziale supporto per luci,ariang e transmission

5.10
---------------------------------------------------------------------------
- UPnP fix thx  Jecht_Sin

5.9
---------------------------------------------------------------------------
- Test wifi fix, thx aezakmi123

5.8
---------------------------------------------------------------------------
- Latenza maggiorata fixata, (disabilitati risparmi energetici per le porte ed il traffico 5ghz

5.7
---------------------------------------------------------------------------
- Fixata finalmente tab assistenza e selettore porte. (questa volta per sempre...)

5.6
---------------------------------------------------------------------------
- Aggiunto uptime wan

5.5
---------------------------------------------------------------------------
- Fixato cpustep, thx @shdf

5.4
---------------------------------------------------------------------------
- Fixato selettore porta nella tab assist

5.3
---------------------------------------------------------------------------
- Aggiunto selettore driver xdsl

5.2
---------------------------------------------------------------------------
- ReRefix tab lan e fix css per primo root

5.1
---------------------------------------------------------------------------
- Refix tab lan e fix cwmpd (forse)

5.0
---------------------------------------------------------------------------
- Fix autocompletamento e tab lan

4.6
---------------------------------------------------------------------------
- Fixato switch tab mobile

4.5
---------------------------------------------------------------------------
- Selettore skin gui nella tab Sistema Extra

4.4
---------------------------------------------------------------------------
- Fix pagina wireless

4.3
---------------------------------------------------------------------------
- Traduzioni aggiornate (thx @DarkNiko), altri fix telegestione e altro

4.2
---------------------------------------------------------------------------
- Altri fix, gui stabile

4.1
---------------------------------------------------------------------------
- Vari fix, telegestione fixata (forse? no...), gui stabile

4.0
---------------------------------------------------------------------------
- Rebase Completo
---------------------------------------------------------------------------
# Mainline 17.1 Aqua

3.36
---------------------------------------------------------------------------
- Fix grafico 5Ghz

3.35
---------------------------------------------------------------------------
- Svecchiamento grafica pt.2

3.34
---------------------------------------------------------------------------
- Fix grafico lan

3.33
---------------------------------------------------------------------------
- Migliorata velocità gui

3.32
---------------------------------------------------------------------------
- Migliorata configurazione wizard voip (chiede anche il resto ora....)

3.31
---------------------------------------------------------------------------
- Aggiunte voci domain name e realm sezione voip

3.30
---------------------------------------------------------------------------
- Fix riattivazione dhcp e bridge mode

3.29
---------------------------------------------------------------------------
- Fix telegestione

3.28
---------------------------------------------------------------------------
- Testing accesso remoto con scelta di porta. (Necessario un reboot per cambiare la porta)

3.27
---------------------------------------------------------------------------
- Aggiornato nginx, attivato gzip compression aumentata reattività webui

3.26
---------------------------------------------------------------------------
- Fixed opkg update problem (openssl-util manuallty installed) and mac address

3.25
---------------------------------------------------------------------------
- Verde è più bello :)

3.24
---------------------------------------------------------------------------
- Fix vari, wizard fixato

3.23
---------------------------------------------------------------------------
- Aggiunto Traffic Monitor nella sezione dispositivi

3.22
---------------------------------------------------------------------------
- Fix vari

3.21
---------------------------------------------------------------------------
- Fix bug aggiornamento disponibile

3.20
---------------------------------------------------------------------------
- Aggiunto update gui offline e fix vari

3.19
---------------------------------------------------------------------------
- Nuovi pacchetti (kmod funzionanti), aggiornato opkg repo. Si ringrazia Roleo per la compilazione

3.18
---------------------------------------------------------------------------
- Introdotto nuovo daemon dlnad

3.17
---------------------------------------------------------------------------
- Fix sysupgrade (flash altra partizione ma niente switchover, ora flasha quella su cui è presente il firmware e non esegue switchover)

3.16
---------------------------------------------------------------------------
- Rimosso aggiornamento adsl e cwmpd... 

3.15
---------------------------------------------------------------------------
- Possibile fix tod wireless

3.14
---------------------------------------------------------------------------
- Fix card_limiter

3.13
---------------------------------------------------------------------------
- Fix per user non telecom

3.12
---------------------------------------------------------------------------
- Miglioramento script root e aggiunte alcune traduzioni

3.11
---------------------------------------------------------------------------
- Disabilitato daemon ipv6, per ora è comunque buggato e rotto

3.10
---------------------------------------------------------------------------
- Bottone Bridge Fixato @Pigr8. Opkg quasi funzionante, provare ad installare i pacchetti 
- e segnalare quali funzionanti.

3.9
---------------------------------------------------------------------------
- Fixato telnet e pagina password

3.8
---------------------------------------------------------------------------
- Fixato problema aggiornamento convertito in reset... 
- (causato da un mio errore per aver introdotto script nel posto sbagliato)

3.7
---------------------------------------------------------------------------
- Probabile fix al bug del dns

3.6
---------------------------------------------------------------------------
- Aggiunto switch per disattivare check bank_1 (Funzioni Avanzate)

3.5
---------------------------------------------------------------------------
- Fixato bug password

3.4
---------------------------------------------------------------------------
- Refactor platform.sh e script di root per l'upgrade della versione

3.3
---------------------------------------------------------------------------
- Aggiornato driver xDSL

3.2
---------------------------------------------------------------------------
- Tutti in bank_1, inserito check in boot per forzare tutti lì

3.1
---------------------------------------------------------------------------
- Tab DHCP fixata

3.0
---------------------------------------------------------------------------
- Merge cambiamenti da AGTEF_1.0.4_007
---------------------------------------------------------------------------
# Mainline 17.1 Aqua

2.23
---------------------------------------------------------------------------
- Aggiunto bottone transfer to bank 1 nella tab system (Funzioni Avanzate) 

2.22
---------------------------------------------------------------------------
- Aggiunto bottone switchover e informazioni sui bank nella tab system

2.21
---------------------------------------------------------------------------
- Fixata casella DDNS non visualizzata

2.20
---------------------------------------------------------------------------
- Aggiunto sistema di autoaggiornamento gui e segnalazione nuova versione. (WIP)

2.19
---------------------------------------------------------------------------
- Fixato bug riavvio, fixata tab samba... per il printsharing è necessario abilitare samba.

2.18
---------------------------------------------------------------------------
- Aggiunto card limiter e fixato bug VOICEMODE (si prega di rieseguire la procedura)

2.17
---------------------------------------------------------------------------
- Aggiunta funzione per modalità asstenza permanente e scelta password

2.16
---------------------------------------------------------------------------
- Aggiunte funzioni per il reset TOTALE e il ripristino della gui originale

2.15
---------------------------------------------------------------------------
- Aggiunta visualizzazione codec voip e possibilità di configurarli

2.14
---------------------------------------------------------------------------
- Aggiunto WakeOnWan e fixata visualizzazione e funzione del portforward

2.13
---------------------------------------------------------------------------
- Piccola rivisitazione grafica, aggiunta icone e inseriti controlli SSH e Telnet in Funzioni Extra di Sistema

2.12
---------------------------------------------------------------------------
- Aggiunto Telnet e reso attivabile da gui (tab Funzioni Avanzate)

2.11
---------------------------------------------------------------------------
- Resi funzionali BridgeMode e VoiceMode

2.10
---------------------------------------------------------------------------
- Fixato invalid istance nel SetupWizard.

2.9
---------------------------------------------------------------------------
- Fixato il QOS.

2.8
---------------------------------------------------------------------------
- Altre traduzioni alla gui by DarkNiko.

2.7
---------------------------------------------------------------------------
- Fixato bug per il quale non era possibile creare regole di port forward.

2.6
---------------------------------------------------------------------------
- Vari fix e aggiornamenti alla traduzione della webui. Si ringrazia DarkNiko per l'ottimo lavoro.

2.5
---------------------------------------------------------------------------
- Fixate/Rimosse le Invalid Istance, aggiunta possibilità di modificare regole qos.

2.4
---------------------------------------------------------------------------
- Aggiunte impostazioni Hostname nella tab Gateway e Domain Name nella tab Rete Locale

2.3
---------------------------------------------------------------------------
- Sbloccate altre funzioni e perfezionato metodo di sblocco webui. VoiceMode e BridgeMode ancora WIP!

2.2
---------------------------------------------------------------------------
- Fixati alcuni bottoni e aggiunto bottone per controllare aggiornamenti

2.1
---------------------------------------------------------------------------
- Fix bug bypass password

2.0
---------------------------------------------------------------------------
- Merge WebUi firmware beta telecom
---------------------------------------------------------------------------
# Mainline 16.3 Aqua

1.12
---------------------------------------------------------------------------
- Aggiungi bottoni mobile e CWMP

1.11
---------------------------------------------------------------------------
- Aggiunge funzioni eco nella tab Gateway

1.10
---------------------------------------------------------------------------
- FIX IPV6 e aggiunto changelog

1.9
---------------------------------------------------------------------------
- Aggiunte funzioni Risparmio Energetico Configurabili (/etc/config/power)

1.8
---------------------------------------------------------------------------
- Aggiunta password Numero Voip nella visione generale della tab Telefono

1.7
---------------------------------------------------------------------------
- Aggiunta Voice Mode (WIP)

1.6
---------------------------------------------------------------------------
- Aggiunta Bridge Mode (WIP)

1.5
---------------------------------------------------------------------------
- Rimosso blocco degli spazzi nell'ssid

1.4
---------------------------------------------------------------------------
- Inserito conferma per inserimento di password non sicura. (Ora è possibile inserire password minore di 12 caratteri)

1.3
---------------------------------------------------------------------------
- Aggiunto Wizard (WIP)

1.2
---------------------------------------------------------------------------
- Aggiunte tab switch e QOS (WIP)

1.1
---------------------------------------------------------------------------
- Abilitate tab nascoste

1.0
---------------------------------------------------------------------------
- Rimosso css e logo tim"