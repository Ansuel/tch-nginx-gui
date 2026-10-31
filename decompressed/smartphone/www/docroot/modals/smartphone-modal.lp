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
            data_on = true, data_off = true, start_vpn = true, stop_vpn = true }
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

    ngx.print('<form class="form-horizontal">')
    ngx.print('<input type="hidden" id="global-csrf-token" name="CSRFtoken" value="' .. session:getCSRFtoken() .. '">')

    local lbl = { span = { class = "span4" } }

    ngx.print('<div class="alert alert-warning" id="phone-error"' .. (d.ERROR and '' or ' style="display:none"') .. '>' .. (d.ERROR or '') .. '</div>')
    ngx.print('<fieldset><legend>Informazioni Dispositivo</legend>')
    ngx.print(ui_helper.createLabel("Modello:", '<span id="live_model">' .. (d.DEV or d.USB_DEV or "N/A") .. '</span>', lbl))
    ngx.print(ui_helper.createLabel("Potenza Segnale:", '<span id="live_sig">'..(d.SIG or "N/A")..'</span>', lbl))
    ngx.print(ui_helper.createLabel("Dati Cellulari:", '<span id="live_data">' .. (d.DATA_ST == "1" and "Attivi" or "Inattivi") .. '</span>', lbl))
    ngx.print('</fieldset>')

    local function host_link(data)
        if not data.HOST_IF then return data.USB_NETWORK == "1" and "Interfaccia non rilevata" or "N/A" end
        return data.HOST_ADMIN == "up" and data.HOST_CARRIER == "1" and "Attivo" or "Inattivo"
    end
    ngx.print('<fieldset><legend>Tethering sul router</legend>')
    ngx.print(ui_helper.createLabel("Interfaccia:", '<span id="host_if">' .. (d.HOST_IF or "N/A") .. '</span>', lbl))
    ngx.print(ui_helper.createLabel("Link USB:", '<span id="host_link">' .. host_link(d) .. '</span>', lbl))
    ngx.print(ui_helper.createLabel("IPv4:", '<span id="host_ipv4">' .. (d.HOST_IPV4 or "Non assegnato") .. '</span>', lbl))
    ngx.print(ui_helper.createLabel("Gateway:", '<span id="host_gateway">' .. (d.HOST_GATEWAY or "Non configurato") .. '</span>', lbl))
    ngx.print(ui_helper.createLabel("Velocità USB:", '<span id="host_speed">' .. (d.USB_SPEED and (d.USB_SPEED .. " Mbit/s") or "N/A") .. '</span>', lbl))
    ngx.print(ui_helper.createLabel("Moduli caricati:", '<span id="host_modules">' .. (d.HOST_MODULES or "Nessuno rilevato") .. '</span>', lbl))
    ngx.print(ui_helper.createLabel("Installazione driver:", '<span id="host_drivers">' .. (d.HOST_DRIVER_STATUS or "N/A") .. '</span>', lbl))
    ngx.print('<p>Il link USB non indica che il router stia usando il telefono come accesso Internet. La WAN va configurata separatamente.</p></fieldset>')

    ngx.print('<fieldset><legend>Batteria e Salute</legend>')
    ngx.print(ui_helper.createLabel("Livello:", '<span id="live_batt">'..(d.BATT or "N/A")..'</span>', lbl))
    ngx.print(ui_helper.createLabel("Stato:", '<span id="live_batt_stat">'..(d.BATT_STAT or "N/A")..'</span>', lbl))
    ngx.print(ui_helper.createLabel("Salute:", '<span id="live_batt_health">'..(d.BATT_HEALTH or "N/A")..'</span>', lbl))
    ngx.print(ui_helper.createLabel("Temperatura:", '<span id="live_temp">'..(d.TEMP or "N/A")..'</span>', lbl))
    ngx.print(ui_helper.createLabel("Voltaggio:", '<span id="live_volt">'..(d.VOLT or "N/A")..'</span>', lbl))
    ngx.print('</fieldset>')

    ngx.print('<fieldset><legend>Sistema e Tethering</legend>')
    ngx.print(ui_helper.createLabel("Stato USB:", '<span id="live_usb">'..(d.USB_STATE or "N/A")..'</span>', lbl))
    ngx.print(ui_helper.createLabel("Tethering:", '<span id="live_tether">'..(d.TETHER or "N/A")..'</span>', lbl))
    if d.ROOT_ACCESS == "1" then ngx.print(ui_helper.createLabel("VPN Condivisa:", '<strong><span id="live_vpn_share" style="color:#2cdb46;">'..(d.VPN_SHARE or "N/A")..'</span></strong>', lbl)) end
    ngx.print(ui_helper.createLabel("Carico CPU:", '<span id="live_load">'..(d.LOAD or "N/A")..'</span>', lbl))
    ngx.print(ui_helper.createLabel("Memoria RAM:", '<span id="live_mem">'..(d.MEM or "N/A")..'</span>', lbl))
    ngx.print('</fieldset>')

    ngx.print('<fieldset><legend>Dettagli Rete e Cella</legend>')
    ngx.print(ui_helper.createLabel("Operatore:", d.OPER or "N/A", lbl))
    ngx.print(ui_helper.createLabel("Tecnologia:", '<span id="live_net">'..(d.NET or "N/A")..'</span>', lbl))
    ngx.print(ui_helper.createLabel("Banda:", '<span id="live_band">'..((d.BAND or "N/A")..(d.BAND_SOURCE == "EARFCN" and " (da EARFCN)" or ""))..'</span>', lbl))
    ngx.print(ui_helper.createLabel("Qualità (RSRQ):", '<span id="live_rsrq">'..(d.RSRQ or "N/A")..'</span>', lbl))
    ngx.print(ui_helper.createLabel("Rapporto segnale/rumore (RSSNR):", '<span id="live_snr">'..(d.SNR or "N/A")..'</span>', lbl))
    ngx.print(ui_helper.createLabel("PCI:", '<span id="live_pci">'..(d.PCI or "N/A")..'</span>', lbl))
    ngx.print(ui_helper.createLabel("eNB ID (LTE):", '<span id="live_enb">'..(d.ENB or "N/A")..'</span>', lbl))
    ngx.print(ui_helper.createLabel("Settore (LTE):", '<span id="live_sector">'..(d.SECTOR or "N/A")..'</span>', lbl))
    ngx.print(ui_helper.createLabel("ECI (LTE):", '<span id="live_eci">'..(d.ECI or "N/A")..'</span>', lbl))
    ngx.print(ui_helper.createLabel("ECGI (MCC-MNC-ECI):", '<span id="live_ecgi">'..(d.ECGI or "N/A")..'</span>', lbl))
    ngx.print(ui_helper.createLabel("TAC (LTE):", '<span id="live_tac">'..(d.TAC or "N/A")..'</span>', lbl))
    ngx.print(ui_helper.createLabel("EARFCN (LTE):", '<span id="live_earfcn">'..(d.EARFCN or "N/A")..'</span>', lbl))
    ngx.print(ui_helper.createLabel("Slot SIM:", '<span id="live_sim_slot">'..(d.SIM_SLOT or "N/A")..'</span>', lbl))
    ngx.print('</fieldset>')

    ngx.print('<fieldset><legend>Grafico Segnale (RSRP)</legend>')
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
      timeout: 25000,
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

  $(document).ready(function(){
    $(".loading").hide();
    $("#lte-body").removeClass("loading-hidden").css("visibility","visible");

    function stopPolling() {
        isModalActive = false;
        clearTimeout(pollTimer);
        if(currentAjax) currentAjax.abort();
    }
    var modal = $('#lte-body').closest('.modal');
    modal.one('hidden', stopPolling);
    modal.find('.nav-tabs a, [data-dismiss="modal"]').one('click', stopPolling);

    var pts=[];
    var plot=$.plot("#live-chart",[{data:[],label:" RSRP (dBm)"}],{
      series:{lines:{show:true,fill:true,fillColor:"rgba(93,33,93,0.2)"}},
      colors:["#5d215d"], yaxis:{min:-120,max:-60}, xaxis:{show:false}
    });

    function update(){
      if (!isModalActive || !document.getElementById('live-chart')) return;

      postSmartphone("get_stats", function(j){
        if (!isModalActive) return;

        if (!document.getElementById('live-chart')) { isModalActive = false; return; }
        var error = j.ERROR || (j.status === "error" && j.message);
        $("#phone-error").text(error || "").toggle(!!error);
        $("#live_model").text(j.DEV || j.USB_DEV || "N/A");
        $("#host_if").text(j.HOST_IF || "N/A");
        $("#host_link").text(j.HOST_IF ? (j.HOST_ADMIN === "up" && j.HOST_CARRIER === "1" ? "Attivo" : "Inattivo") :
            (j.USB_NETWORK === "1" ? "Interfaccia non rilevata" : "N/A"));
        $("#host_ipv4").text(j.HOST_IPV4 || "Non assegnato");
        $("#host_gateway").text(j.HOST_GATEWAY || "Non configurato");
        $("#host_speed").text(j.USB_SPEED ? j.USB_SPEED + " Mbit/s" : "N/A");
        $("#host_modules").text(j.HOST_MODULES || "Nessuno rilevato");
        $("#host_drivers").text(j.HOST_DRIVER_STATUS || "N/A");
        $("#live_data").text(j.DATA_ST === "1" ? "Attivi" : "Inattivi");
        $(".phone-root-control").toggle(j.ROOT_ACCESS === "1");
        $(".phone-tailscale-control").toggle(j.ROOT_ACCESS === "1" && j.TAILSCALE_CLI === "1");
        $("#btn_screen_capture").toggle(j.SCREEN_CAPTURE === "1");
        var val=Number(j.SIGNAL_RAW);
        if(!isNaN(val)){ if(pts.length>=30) pts.shift(); pts.push(val); }
        var res=[]; for(var i=0;i<pts.length;i++) res.push([i,pts[i]]);
        plot.setData([{data:res}]); plot.draw();

        $("#live_batt").text(j.BATT || "N/A");
        $("#live_batt_stat").text(j.BATT_STAT || "N/A");
        $("#live_batt_health").text(j.BATT_HEALTH || "N/A");
        $("#live_volt").text(j.VOLT || "N/A");
        $("#live_temp").text(j.TEMP || "N/A");
        $("#live_sig").text(j.SIG || "N/A");
        $("#live_net").text(j.NET || "N/A");
        $("#live_band").text((j.BAND || "N/A") + (j.BAND_SOURCE === "EARFCN" ? " (da EARFCN)" : ""));
        $("#live_rsrq").text(j.RSRQ || "N/A");
        $("#live_snr").text(j.SNR || "N/A");
        $("#live_pci").text(j.PCI || "N/A");
        $("#live_enb").text(j.ENB || "N/A");
        $("#live_sector").text(j.SECTOR || "N/A");
        $("#live_eci").text(j.ECI || "N/A");
        $("#live_ecgi").text(j.ECGI || "N/A");
        $("#live_tac").text(j.TAC || "N/A");
        $("#live_earfcn").text(j.EARFCN || "N/A");
        $("#live_sim_slot").text(j.SIM_SLOT || "N/A");
        $("#live_usb").text(j.USB_STATE || "N/A");
        $("#live_tether").text(j.TETHER || "N/A");
        $("#live_load").text(j.LOAD || "N/A");
        $("#live_mem").text(j.MEM || "N/A");

        if(j.VPN_SHARE && j.VPN_SHARE === "Attiva") {
            vpnIsActive = true;
            $("#live_vpn_share").text("Attiva (Inoltro in corso)");
            $("#btn_vpn").removeClass("btn-success").addClass("btn-danger").html('<i class="icon-unlock"></i> Disattiva VPN');
        } else {
            vpnIsActive = false;
            $("#live_vpn_share").text("Inattiva");
            $("#btn_vpn").removeClass("btn-danger").addClass("btn-success").html('<i class="icon-lock"></i> Condividi VPN');
        }

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
