--pretranslated: do not change this file
gettext.textdomain('webui-mobiled')
local ngx = ngx
local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local session = ngx.ctx.session
local lp = require("web.lp")
local json = require("dkjson")
local function read_phone(parameter)
    local result = proxy.get("rpc.smartphone." .. parameter)
    if not result or not result[1] then return nil, "Smartphone backend unavailable" end
    local text = string.untaint(result[1].value)
    local err = text:match("^ERROR|([^\r\n]+)")
    if err then return nil, err, text:match("\nERROR_CODE|([a-z_]+)"), text end
    return text
end
local function get_phone_data()
    local payload, err, code, diagnostics = read_phone("stats")
    local d = {}
    for line in (payload or diagnostics or ""):gmatch("[^\r\n]+") do
        local k, v = line:match("^([^|]+)|(.+)$")
        if k and v then d[k] = v end
    end
    d.ERROR = err
    d.ERROR_CODE = code
    return d
end
if ngx.req.get_method() == "POST" then
    -- get_post_args validates CSRF through web.web before returning tainted input.
    local post = ngx.req.get_post_args()
    local action = string.untaint(post.action)
    local response = {status = "ok"}
    if action == "get_stats" then
        response = get_phone_data()
    elseif action == "get_peers" then
        local text, err = read_phone("peers")
        response = { status = err and "error" or "ok", message = text or err }
    else
        local allowed = { screen_wake = true, screen_sleep = true, capture_screen = true, reboot = true, reconnect_data = true,
            data_on = true, data_off = true, start_vpn = true, stop_vpn = true,
            uplink_link = true, uplink_fallback = true, uplink_primary = true, uplink_stop = true,
            usb_ncm = true, usb_rndis = true }
        if type(action) ~= "string" or not allowed[action] then
            ngx.status = ngx.HTTP_BAD_REQUEST
            response = {status = "error", message = "Unsupported smartphone action"}
        else
            local ok, errors = proxy.set("rpc.smartphone.action", action)
            response.status = ok and "ok" or "error"
            local messages = {
                screen_wake = "Comando di accensione del display inviato. Il telefono resta bloccato se era bloccato.",
                screen_sleep = "Comando di spegnimento del display inviato.",
                capture_screen = "Immagine acquisita.",
                reboot = "Riavvio del telefono richiesto.",
                uplink_link = "Collegamento DHCP avviato. La linea Internet principale resta invariata.",
                uplink_fallback = "Telefono impostato come fallback della WAN. Attendere DHCP e verifica connettività.",
                uplink_primary = "Telefono impostato come linea principale; la WAN sarà usata come fallback.",
                uplink_stop = "Tethering disattivato e configurazione precedente ripristinata.",
                usb_ncm = "Modalità CDC NCM confermata.",
                usb_rndis = "Modalità RNDIS confermata.",
            }
            response.message = ok and (messages[action] or "Comando completato.") or "Comando non riuscito: verificare telefono e collegamento USB."
            if not ok and type(errors) == "table" and errors[1] and errors[1].errmsg then
                response.message = string.untaint(errors[1].errmsg)
            end
            if not ok then ngx.status = ngx.HTTP_BAD_REQUEST end
        end
    end
    ngx.header.content_type = "application/json"
    ngx.print(json.encode(response))
    return ngx.exit(ngx.HTTP_OK)
end

    local d = get_phone_data()
    local html_escape = require("web.web").html_escape
    for k, v in pairs(d) do d[k] = html_escape(v) end
    ngx.print('\n<script type="text/javascript" src="/js/flot-min.js"></script>\n')
    ngx.print(ui_helper.createHeader("Dettagli Smartphone", false, true))
    ngx.print('\n<div class="modal-body update no-save" id="lte-body">\n')

    ngx.print('<form class="form-horizontal" action="/modals/smartphone-modal.lp">')
    ngx.print('<input type="hidden" id="global-csrf-token" name="CSRFtoken" value="' .. session:getCSRFtoken() .. '">')

    local lbl = { span = { class = "span4" } }
    local function available(value)
        return value and value:match("%S") and value ~= "N/A"
    end
    local function withUnit(value, suffix)
        return available(value) and (value .. suffix) or nil
    end
    local function row(label, id, value, status)
        local markup
        if status then
            local icons = {
                online = "icon-ok icon-large green",
                offline = "icon-ban-circle icon-large red",
                checking = "icon-time",
            }
            markup = '<i aria-hidden="true" class="' .. (icons[status] or "") .. '"></i> '
        end
        markup = (markup or "") .. '<span id="' .. id .. '">' .. (available(value) and value or "") .. '</span>'
        ngx.print('<div class="phone-stat"' .. (available(value) and '' or ' style="display:none"') .. '>',
            ui_helper.createLabel(label, markup, lbl), '</div>')
    end
    local function section(title, rows)
        local visible = false
        for _, item in ipairs(rows) do
            if available(item[3]) then visible = true; break end
        end
        ngx.print('<fieldset class="phone-stat-section"' .. (visible and '' or ' style="display:none"') ..
            '><legend>' .. title .. '</legend>')
        for _, item in ipairs(rows) do row(item[1], item[2], item[3], item[4]) end
        ngx.print('</fieldset>')
    end
    local function binaryStatus(value, yes, no)
        if value == "1" then return yes, "online" end
        if value == "0" then return no, "offline" end
        return nil, ""
    end
    local function interfaceStatus()
        if d.HOST_IF then return d.HOST_IF, "" end
        if d.HOST_UNBOUND_DRIVER then
            return "Nessuna interfaccia USB: driver " .. d.HOST_UNBOUND_DRIVER .. " non associato", "offline"
        end
        if d.USB_NETWORK == "1" then return "Interfaccia non rilevata", "offline" end
        return nil, ""
    end
    local function linkStatus()
        if d.HOST_IF and d.HOST_ADMIN == "up" and d.HOST_CARRIER == "1" then return "Attivo", "online" end
        if d.HOST_IF and (d.HOST_ADMIN == "down" or d.HOST_CARRIER == "0") then return "Inattivo", "offline" end
        return nil, ""
    end
    local health = {online = "Raggiungibile", offline = "Non raggiungibile", checking = "In verifica", disabled = "Monitor disattivato"}
    local modes = {off = "Disattivato", link = "Solo DHCP", fallback = "Telefono di riserva", primary = "Telefono principale"}
    local lines = {phone = "Telefono", wan = "WAN", none = "Nessuna linea selezionata"}

    ngx.print('<div class="alert alert-warning" id="phone-error"' .. (d.ERROR and '' or ' style="display:none"') .. '>' .. (d.ERROR or '') .. '</div>')
    section("Informazioni Dispositivo", {
        {"Modello:", "live_model", d.DEV or d.USB_DEV},
        {"Potenza Segnale:", "live_sig", d.SIG},
        {"Dati Cellulari:", "live_data", binaryStatus(d.DATA_ST, "Attivi", "Inattivi")},
    })

    ngx.print('<fieldset><legend>Tethering sul router</legend>')
    row("Interfaccia:", "host_if", interfaceStatus())
    row("Driver in uso:", "host_driver", d.HOST_DRIVER)
    row("Link USB:", "host_link", linkStatus())
    row("IPv4:", "host_ipv4", d.HOST_IPV4)
    row("Gateway DHCP:", "host_gateway", d.HOST_GATEWAY or d.UPLINK_GATEWAY)
    row("Velocità USB:", "host_speed", withUnit(d.USB_SPEED, " Mbit/s"))
    row("Moduli caricati:", "host_modules", d.HOST_MODULES)
    row("Installazione driver:", "host_drivers", d.HOST_DRIVER_STATUS)
    ngx.print('<label for="phone-usb-mode">Modalità USB:</label><select id="phone-usb-mode">' ..
        '<option value="">Seleziona modalità</option>' ..
        '<option value="rndis"' .. (d.HOST_RNDIS ~= "1" and ' disabled' or '') .. '>RNDIS</option>' ..
        '<option value="ncm"' .. (d.HOST_NCM ~= "1" and ' disabled' or '') .. '>CDC NCM</option></select> ' ..
        '<button type="button" class="btn" id="phone-usb-apply" onclick="applyPhoneUsbMode()" disabled>Applica modalità USB</button>' ..
        '<p>Con il debug USB autorizzato, il router prova CDC NCM quando il tethering è attivo e il driver è disponibile. Seleziona RNDIS per mantenerlo anche ai collegamenti successivi. Il cambio interrompe temporaneamente il tethering.</p>' ..
        '<p id="phone-usb-ncm-note"' .. (d.HOST_NCM_BLOCKED == "1" and '' or ' style="display:none"') ..
        '>Cambio a CDC NCM disabilitato su questo kernel per evitare blocchi della rete.</p>' ..
        '<p id="phone-usb-result" role="status"></p>')
    ngx.print('</fieldset>')
    ngx.print('<fieldset><legend>Priorità Internet (IPv4)</legend>')
    ngx.print('<p>Abilita il tethering USB sul telefono. DHCP e fallback sul router funzionano anche senza autorizzazione ADB.</p>')
    local selected_mode = (d.UPLINK_MODE == "link" or d.UPLINK_MODE == "primary") and d.UPLINK_MODE or "fallback"
    local function uplink_option(value, label)
        return '<option value="' .. value .. '"' .. (selected_mode == value and ' selected' or '') .. '>' .. label .. '</option>'
    end
    ngx.print('<label for="phone-uplink-mode">Uso del telefono:</label><select id="phone-uplink-mode">' ..
        uplink_option("link", "Solo collegamento DHCP") ..
        uplink_option("fallback", "Fallback della WAN attuale") ..
        uplink_option("primary", "Linea principale; WAN attuale come fallback") .. '</select> ' ..
        '<button type="button" class="btn btn-primary phone-uplink-action" onclick="applyPhoneUplink()">Attiva / Applica</button> ' ..
        '<button type="button" class="btn phone-uplink-action" onclick="stopPhoneUplink()">Disattiva e ripristina</button>')
    ngx.print('<p id="phone-uplink-result" role="status"></p>')
    row("Modalità applicata:", "uplink-mode", modes[d.UPLINK_MODE])
    row("Altra WAN:", "uplink-wan", d.UPLINK_WAN)
    row("Linea in uso:", "uplink-active", lines[d.UPLINK_ACTIVE])
    row("Disponibilità WAN:", "uplink-wan-health", health[d.UPLINK_WAN_HEALTH], d.UPLINK_WAN_HEALTH or "")
    row("Disponibilità telefono:", "uplink-phone-health", health[d.UPLINK_PHONE_HEALTH], d.UPLINK_PHONE_HEALTH or "")
    row("Monitor:", "uplink-message", d.UPLINK_MESSAGE)
    ngx.print('<p>Il monitor controlla 1.1.1.1 e 9.9.9.9 tramite ciascuna linea. Tre controlli falliti attivano il fallback; due successi ripristinano la linea preferita. Le connessioni esistenti possono richiedere una riconnessione. IPv6 e le policy di routing già marcate mantengono la configurazione del router.</p></fieldset>')

    section("Batteria e Salute", {
        {"Livello:", "live_batt", d.BATT},
        {"Stato:", "live_batt_stat", d.BATT_STAT},
        {"Salute:", "live_batt_health", d.BATT_HEALTH},
        {"Temperatura:", "live_temp", d.TEMP},
        {"Voltaggio:", "live_volt", d.VOLT},
    })
    section("Sistema e Tethering", {
        {"Stato USB:", "live_usb", d.USB_STATE},
        {"Tethering:", "live_tether", d.TETHER},
        {"VPN Condivisa:", "live_vpn_share", d.ROOT_ACCESS == "1" and d.VPN_SHARE or nil},
        {"Carico CPU:", "live_load", d.LOAD},
        {"Memoria RAM:", "live_mem", d.MEM},
    })
    section("Dettagli Rete e Cella", {
        {"Operatore:", "live_oper", d.OPER},
        {"Tecnologia:", "live_net", d.NET},
        {"Banda:", "live_band", withUnit(d.BAND, d.BAND_SOURCE == "EARFCN" and " (da EARFCN)" or "")},
        {"LTE RSRQ:", "live_rsrq", withUnit(d.RSRQ, " dB")},
        {"LTE RSSNR:", "live_snr", d.SNR},
        {"5G NR SS-RSRP:", "live_nr_rsrp", withUnit(d.NR_RSRP, " dBm")},
        {"5G NR SS-RSRQ:", "live_nr_rsrq", withUnit(d.NR_RSRQ, " dB")},
        {"5G NR SS-SINR:", "live_nr_sinr", withUnit(d.NR_SINR, " dB")},
        {"PCI:", "live_pci", d.PCI},
        {"eNB ID (LTE):", "live_enb", d.ENB},
        {"Settore (LTE):", "live_sector", d.SECTOR},
        {"ECI (LTE):", "live_eci", d.ECI},
        {"ECGI (MCC-MNC-ECI):", "live_ecgi", d.ECGI},
        {"TAC (LTE):", "live_tac", d.TAC},
        {"EARFCN (LTE):", "live_earfcn", d.EARFCN},
        {"Slot SIM:", "live_sim_slot", d.SIM_SLOT},
    })

    ngx.print('<fieldset id="phone-signal-chart" style="display:none"><legend>Grafico Segnale (RSRP)</legend>')
    ngx.print('<div id="live-chart" style="width: 100%; height: 200px; padding: 10px;"></div>')
    ngx.print('</fieldset>')

    ngx.print('<fieldset id="tailscale-panel" style="display:none; margin-top:10px; border: 1px solid; padding: 10px; border-radius: 5px;">')
    ngx.print('<legend style=" font-size:14px;"><i class="icon-globe"></i> Dispositivi Tailscale Connessi</legend>')
    ngx.print('<pre id="tailscale-peers" style="background-color:#1e1e1e; color:#00ff00; font-family:monospace; font-size:12px; max-height: 200px; overflow-y: auto;">Caricamento in corso...</pre>')
    ngx.print('</fieldset>')

    ngx.print('<div style="text-align:center; margin:15px 0;">')
    ngx.print('<button type="button" class="btn" onclick="sendAdb(\'screen_wake\')">Accendi display</button> ')
    ngx.print('<button type="button" class="btn" onclick="sendAdb(\'screen_sleep\')">Spegni display</button> ')
    if d.SCREEN_CAPTURE == "1" then
        ngx.print('<button type="button" class="btn btn-info" id="btn_screen_capture" onclick="capturePhoneScreen()">Mostra schermo</button> ')
    end
    if d.ROOT_ACCESS == "1" then
        ngx.print('<button type="button" class="btn btn-warning phone-root-control" onclick="sendAdb(\'reconnect_data\')">Riavvia dati</button> ')
        ngx.print('<button type="button" class="btn btn-success phone-root-control" id="btn_vpn" onclick="toggleVpn()">Condividi VPN</button> ')
        if d.TAILSCALE_CLI == "1" then
            ngx.print('<button type="button" class="btn btn-info phone-root-control phone-tailscale-control" onclick="getPeers()">Rete VPN</button> ')
        end
    end
    ngx.print('<button type="button" class="btn btn-danger" onclick="sendAdb(\'reboot\')">Riavvia telefono</button>')
    ngx.print('</div>')
    ngx.print('<fieldset id="phone-screen-panel" style="display:none"><legend>Schermo del telefono</legend>')
    ngx.print('<p>Immagine statica: premi Aggiorna immagine per acquisire lo schermo attuale. Per vederlo acceso usa Accendi display; lo sblocco resta sul telefono.</p>')
    ngx.print('<button type="button" class="btn" onclick="capturePhoneScreen()">Aggiorna immagine</button> <span id="phone-screen-status"></span>')
    ngx.print('<div><img id="phone-screen-image" alt="Cattura dello schermo del telefono" style="display:none;max-width:100%;max-height:650px;margin:10px auto"></div></fieldset>')
    ngx.print('</form></div>')

    ngx.print(ui_helper.createFooter())

    ngx.print([===[
    <script>
  var isModalActive = true;
  var currentAjax = null;
  var pollTimer = null;

  var vpnIsActive = false;

  function toggleVpn() {
    var act = vpnIsActive ? "stop_vpn" : "start_vpn";
    postSmartphone(act, function(res){
        if(res && res.message) alert(res.message);
        else alert("Nessuna risposta dal telefono.");
    });
  }

  function getPeers() {
    $("#tailscale-panel").slideDown();
    $("#tailscale-peers").text("Interrogazione nodo Tailscale in corso... attendere.");
    postSmartphone("get_peers", function(res){
        if(res && res.message) {
            $("#tailscale-peers").text(res.message);
        } else {
            $("#tailscale-peers").text("Errore: Impossibile recuperare i dati dalla VPN.");
        }
    });
  }

  function postSmartphone(action, cb){
    if(!isModalActive) return;
    var tok = $('input[name="CSRFtoken"]').val() || $('meta[name="CSRFtoken"]').attr('content');
    if(!tok || tok.length < 5){
      pollTimer = setTimeout(function(){ postSmartphone(action, cb); }, 1000);
      return;
    }
    currentAjax = $.ajax({
      url: "/modals/smartphone-modal.lp",
      type: "POST", dataType: "json",
      timeout: /^(uplink|usb)_/.test(action) ? 45000 : 25000,
      contentType: "application/x-www-form-urlencoded; charset=UTF-8",
      data: { action: action, CSRFtoken: tok },
      success: function(j){ if(cb && isModalActive) cb(j); },
      error: function(xhr){ if(cb && isModalActive) cb(xhr.responseJSON || {status: "error", message: "Richiesta smartphone fallita."}); }
    });
  }

  function capturePhoneScreen(){
    $("#phone-screen-panel").show();
    $("#phone-screen-status").text("Acquisizione in corso...");
    $("#btn_screen_capture").prop("disabled", true);
    postSmartphone("capture_screen", function(res){
      $("#btn_screen_capture").prop("disabled", false);
      if (!res || res.status !== "ok") {
        $("#phone-screen-status").text((res && res.message) || "Impossibile acquisire lo schermo.");
        return;
      }
      $("#phone-screen-image").one("load", function(){
        $(this).show();
        $("#phone-screen-status").text("Ultima cattura: " + new Date().toLocaleTimeString());
      }).one("error", function(){
        $("#phone-screen-status").text("Impossibile caricare l'immagine.");
      }).attr("src", "/modals/smartphone-screen.lp?t=" + Date.now());
    });
  }

  function sendAdb(c){
    if(c=="reboot" && !confirm("Vuoi riavviare completamente lo smartphone?")) return;
    if(c=="reconnect_data" && !confirm("Disconnettere e riconnettere la linea dati del telefono?")) return;
    postSmartphone(c, function(res){
        if(res && res.message) alert(res.message);
        else alert("Il telefono non ha confermato il comando.");
    });
  }

  function changePhoneUplink(action){
    $(".phone-uplink-action").prop("disabled",true);
    $("#phone-uplink-result").text("Applicazione configurazione in corso...");
    postSmartphone(action,function(res){
      $(".phone-uplink-action").prop("disabled",false);
      $("#phone-uplink-result").text(res && res.message || "Nessuna risposta dal router.");
    });
  }
  function applyPhoneUplink(){
    var mode=$("#phone-uplink-mode").val();
    if (!/^(link|fallback|primary)$/.test(mode)) return;
    changePhoneUplink("uplink_"+mode);
  }
  function stopPhoneUplink(){ changePhoneUplink("uplink_stop"); }

  var usbChanging = false;
  function refreshPhoneUsbButton(){
    $("#phone-usb-apply").prop("disabled", usbChanging || !$("#phone-usb-mode").val());
  }
  function applyPhoneUsbMode(){
    var mode = $("#phone-usb-mode").val();
    if (usbChanging || !/^(ncm|rndis)$/.test(mode)) return;
    if (!confirm("Cambiare modalità USB? La connessione tramite il telefono verrà interrotta.")) return;
    usbChanging = true;
    $("#phone-usb-mode").prop("disabled", true);
    refreshPhoneUsbButton();
    $("#phone-usb-result").text("Cambio modalità USB in corso...");
    postSmartphone("usb_" + mode, function(res){
      usbChanging = false;
      $("#phone-usb-mode").prop("disabled", false);
      refreshPhoneUsbButton();
      $("#phone-usb-result").text(res && res.message || "Nessuna risposta dal router.");
    });
  }

  $(document).ready(function(){
    $(".loading").hide();
    $("#lte-body").removeClass("loading-hidden").css("visibility","visible");

    function stopPolling() {
        modal.off("hide.smartphone tch:modal-content-replacing.smartphone", stopPolling);
        isModalActive = false;
        clearTimeout(pollTimer);
        if(currentAjax) currentAjax.abort();
    }
    var modal = $('#lte-body').closest('.modal');
    modal.on("hide.smartphone tch:modal-content-replacing.smartphone", stopPolling);

    $("#phone-usb-mode").on("change", refreshPhoneUsbButton);
    var ltePoints=[], nrPoints=[], sampleIndex=0, plot;
    var statusIcons={online:"icon-ok icon-large green",offline:"icon-ban-circle icon-large red",checking:"icon-time"};
    var healthLabels={online:"Raggiungibile",offline:"Non raggiungibile",checking:"In verifica",disabled:"Monitor disattivato"};
    var modes={off:"Disattivato",link:"Solo DHCP",fallback:"Telefono di riserva",primary:"Telefono principale"};
    var lines={phone:"Telefono",wan:"WAN",none:"Nessuna linea selezionata"};
    function available(value){
      return typeof value === "string" && /\S/.test(value) && value !== "N/A";
    }
    function withUnit(value, suffix){
      return available(value) ? value + suffix : undefined;
    }
    function showRow(id, value, state){
      var text = $("#" + id), row = text.closest(".phone-stat");
      var visible = available(value);
      text.text(visible ? value : "");
      if (state !== undefined) text.siblings("i").attr("class", statusIcons[state] || "");
      row.toggle(visible);
    }
    function showHealth(id, state){
      showRow(id, healthLabels[state], state || "");
    }
    function showInterface(data){
      if (data.HOST_IF) {
        showRow("host_if", data.HOST_IF, "");
      } else if (data.HOST_UNBOUND_DRIVER) {
        showRow("host_if", "Nessuna interfaccia USB: driver " + data.HOST_UNBOUND_DRIVER + " non associato", "offline");
      } else {
        showRow("host_if", data.USB_NETWORK === "1" ? "Interfaccia non rilevata" : undefined, "offline");
      }
    }
    function showLink(data){
      if (data.HOST_IF && data.HOST_ADMIN === "up" && data.HOST_CARRIER === "1") {
        showRow("host_link", "Attivo", "online");
      } else if (data.HOST_IF && (data.HOST_ADMIN === "down" || data.HOST_CARRIER === "0")) {
        showRow("host_link", "Inattivo", "offline");
      } else {
        showRow("host_link", undefined, "");
      }
    }
    function signalNumber(value){
      return /^-?\d+$/.test(value) ? Number(value) : null;
    }
    function updateChart(data){
      var lte = signalNumber(data.SIGNAL_RAW), nr = signalNumber(data.NR_RSRP);
      var visible = lte !== null || nr !== null;
      $("#phone-signal-chart").toggle(visible);
      if (ltePoints.length >= 30) { ltePoints.shift(); nrPoints.shift(); }
      ltePoints.push([sampleIndex, lte]);
      nrPoints.push([sampleIndex++, nr]);
      if (!visible) return;
      var series = [];
      if (ltePoints.some(function(point){ return point[1] !== null; })) {
        series.push({data:ltePoints,label:"LTE RSRP (dBm)",color:"#5d215d"});
      }
      if (nrPoints.some(function(point){ return point[1] !== null; })) {
        series.push({data:nrPoints,label:"5G NR SS-RSRP (dBm)",color:"#268084"});
      }
      if (!plot) {
        plot = $.plot("#live-chart",series,{
          series:{lines:{show:true}}, yaxis:{min:-156,max:-31}, xaxis:{show:false}
        });
      } else {
        plot.setData(series);
        plot.setupGrid();
        plot.draw();
      }
    }

    function update(){
      if (!isModalActive || !document.getElementById('live-chart')) return;
      if (usbChanging) { pollTimer = setTimeout(update, 1000); return; }

      postSmartphone("get_stats", function(j){
        if (!isModalActive) return;

        if (!document.getElementById('live-chart')) { isModalActive = false; return; }
        var error = j.ERROR || (j.status === "error" && j.message);
        $("#phone-error").text(error || "").toggle(!!error);
        showRow("live_model", j.DEV || j.USB_DEV);
        showInterface(j);
        showRow("host_driver", j.HOST_DRIVER);
        $("#phone-usb-mode option[value=ncm]").prop("disabled", !!error || j.HOST_NCM !== "1");
        $("#phone-usb-mode option[value=rndis]").prop("disabled", !!error || j.HOST_RNDIS !== "1");
        $("#phone-usb-ncm-note").toggle(j.HOST_NCM_BLOCKED === "1");
        refreshPhoneUsbButton();
        showLink(j);
        showRow("host_ipv4", j.HOST_IPV4);
        showRow("host_gateway", j.HOST_GATEWAY || j.UPLINK_GATEWAY);
        showRow("host_speed", withUnit(j.USB_SPEED, " Mbit/s"));
        showRow("host_modules", j.HOST_MODULES);
        showRow("host_drivers", j.HOST_DRIVER_STATUS);
        showRow("uplink-mode", modes[j.UPLINK_MODE]);
        showRow("uplink-wan", j.UPLINK_WAN);
        showRow("uplink-active", lines[j.UPLINK_ACTIVE]);
        showRow("uplink-message", j.UPLINK_MESSAGE);
        showHealth("uplink-wan-health", j.UPLINK_WAN_HEALTH);
        showHealth("uplink-phone-health", j.UPLINK_PHONE_HEALTH);
        if (j.DATA_ST === "1") showRow("live_data", "Attivi", "online");
        else if (j.DATA_ST === "0") showRow("live_data", "Inattivi", "offline");
        else showRow("live_data", undefined, "");
        $(".phone-root-control").toggle(j.ROOT_ACCESS === "1");
        $(".phone-tailscale-control").toggle(j.ROOT_ACCESS === "1" && j.TAILSCALE_CLI === "1");
        $("#btn_screen_capture").toggle(j.SCREEN_CAPTURE === "1");
        updateChart(j);

        showRow("live_batt", j.BATT);
        showRow("live_batt_stat", j.BATT_STAT);
        showRow("live_batt_health", j.BATT_HEALTH);
        showRow("live_volt", j.VOLT);
        showRow("live_temp", j.TEMP);
        showRow("live_sig", j.SIG);
        showRow("live_oper", j.OPER);
        showRow("live_net", j.NET);
        showRow("live_band", withUnit(j.BAND, j.BAND_SOURCE === "EARFCN" ? " (da EARFCN)" : ""));
        showRow("live_rsrq", withUnit(j.RSRQ, " dB"));
        showRow("live_snr", j.SNR);
        showRow("live_nr_rsrp", withUnit(j.NR_RSRP, " dBm"));
        showRow("live_nr_rsrq", withUnit(j.NR_RSRQ, " dB"));
        showRow("live_nr_sinr", withUnit(j.NR_SINR, " dB"));
        showRow("live_pci", j.PCI);
        showRow("live_enb", j.ENB);
        showRow("live_sector", j.SECTOR);
        showRow("live_eci", j.ECI);
        showRow("live_ecgi", j.ECGI);
        showRow("live_tac", j.TAC);
        showRow("live_earfcn", j.EARFCN);
        showRow("live_sim_slot", j.SIM_SLOT);
        showRow("live_usb", j.USB_STATE);
        showRow("live_tether", j.TETHER);
        showRow("live_load", j.LOAD);
        showRow("live_mem", j.MEM);

        vpnIsActive = j.ROOT_ACCESS === "1" && j.VPN_SHARE === "Attiva";
        showRow("live_vpn_share", j.ROOT_ACCESS === "1" ? j.VPN_SHARE : undefined);
        $("#btn_vpn").toggleClass("btn-success", !vpnIsActive).toggleClass("btn-danger", vpnIsActive)
          .html(vpnIsActive ? '<i class="icon-unlock"></i> Disattiva VPN' : '<i class="icon-lock"></i> Condividi VPN');
        $(".phone-stat-section").each(function(){
          var section = $(this);
          section.toggle(section.children(".phone-stat").filter(function(){
            return $(this).css("display") !== "none";
          }).length > 0);
        });

        if (isModalActive) {
            pollTimer = setTimeout(update,5000);
        }
      });
    }
    update();
  });
</script>
    ]===])
    ngx.exit(ngx.HTTP_OK)
