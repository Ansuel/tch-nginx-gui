--pretranslated: do not change this file

-- NG.... hide manual switching if wansensing is enabled
--NG-100650 Set 4th Ethernet Port as WAN or LAN Port on GUI
--NG-102545 GUI broadband is showing SFP Broadband GUI page when Ethernet 4 is connected
-- Enable localization
gettext.textdomain('webui-core')

local lp = require("web.lp")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local dyntab_helper = require("web.dyntab_helper")
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local proxy = require("datamodel")
local session = ngx.ctx.session

local bridgemode = require("bridgedmode_helper")
local voicemode = require("voicemode_helper")

local tech = false
if session:getrole() == "admin" then
	tech = true
end

local bmh = require("broadbandmode_helper")
local tabdata = dyntab_helper.process(bmh)

local mode_current = tabdata.current.name
local mode_options = tabdata.options

local vB = post_helper.validateBoolean
local gOV = post_helper.getOptionalValidation

mapParam = { 
				wsens = "uci.wansensing.global.enable",
				iface = "uci.network.interface.@wan.ifname",
				dsl_status = "sys.class.xdsl.@line0.Status",
				sfp = "uci.env.rip.sfp",
			}

content_helper.getExactContent(mapParam)

--mapParSFP = { ethsfp = "uci.ethernet.globals.eth4lanwanmode" }
--
--mapValSFP = { ethsfp = gOV(vB) }
--
--local content, helpmsg = post_helper.handleQuery(mapParSFP, mapValSFP)

if not tabdata.current.ajax then
   -- only display if not doing an ajax request
if tech and mapParam.sfp == "1" then
	ngx.print(ui_helper.createHeader(T"Broadband", true, true)) 
elseif mapParam.wsens == "1" and (mapParam.dsl_status ~= "Up" or string.match(mapParam.iface,"eth4")) then
	ngx.print(ui_helper.createHeader(T"Broadband", false, true)) 
else
	ngx.print(ui_helper.createHeader(T"Broadband", true, true))
end
	
local function resetreboot(path, value)
  proxy.set(path, value)
  ngx.header.content_type = "application/json"
  ngx.print('{ "success":"true" }')
  ngx.timer.at(0, function()
    proxy.apply()
  end)
  ngx.exit(ngx.HTTP_OK)
end

if ngx.var.request_method == "POST" then
    content1 = ngx.req.get_post_args()
    action = content1["action"]
    if action == "BRIDGEMODE" then
        if not bridgemode.isBridgedMode() then
            bridgemode.configBridgedMode()
            return resetreboot("rpc.system.reboot", "GUI")
        end
    end
end

if ngx.var.request_method == "POST" then
    content1 = ngx.req.get_post_args()
    action = content1["action"]
    if action == "REVERTBRIDGEMODE" then
        if bridgemode.isBridgedMode() then
            bridgemode.disableBridgedMode()
            return resetreboot("rpc.system.reboot", "GUI")
        end
    end
end

if ngx.var.request_method == "POST" then
    content1 = ngx.req.get_post_args()
    action = content1["action"]
    if action == "VOICEMODE" then
        if not voicemode.isVoiceMode() then
            voicemode.configVoiceMode()
            return resetreboot("rpc.system.reboot", "GUI")
        end
    end
end

if ngx.var.request_method == "POST" then
    content1 = ngx.req.get_post_args()
    action = content1["action"]
    if action == "REVERTVOICEMODE" then
        if voicemode.isVoiceMode() then
            voicemode.disableVoiceMode()
            return resetreboot("rpc.system.reboot", "GUI")
        end
    end
end

ngx.print('\
<div class="modal-body update">\
<form class="form-horizontal" method="post" action="modals/broadband-modal.lp">\
')
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
ngx.print('\
<fieldset id="conn_mode" class="advanced hide">\
<legend>');ngx.print(T"Broadband type");ngx.print('</legend>')

    local html = {}

    local mode_attributes = {
        radio = {
            class = "inline"
        },
        input = {
            class = "no-save",
            ["data-for"] = "SWITCH_MODE",
        }
    }
    local mode_button = {
        button = {
            ["data-name"] = "action",
            ["data-value"] = "SWITCH_MODE",
        }
    }

    html[#html+1] = ui_helper.createInputRadio(T"Mode", "newmode", mode_options, mode_current, mode_attributes)
    html[#html+1] = ui_helper.createButton("", T"Switch connection mode", "icon-cog", mode_button)

    ngx.print(html)
ngx.print('\
</fieldset>\
')
--ngx.print('\
--<fieldset id="conn_mode" class="advanced hide">\
--<legend>');ngx.print(T"Set 4th Ethernet Port as WAN or as LAN");ngx.print('</legend>')
--
--	local adv = {
--					values = {
--                    on = "0",
--                    off = "1"
--                  }
--				}
--	local html = {}
--	html[#html + 1] = ui_helper.createSwitch(T"WAN-Mode", "ethsfp", content["ethsfp"], adv)
--	ngx.print(html)
--	ngx.print('\
--</fieldset>\
--')
ngx.print('<fieldset>');
	ngx.print('<legend>'); ngx.print(T"Network mode"); ngx.print('</legend>');
	 
	if not bridgemode.isBridgedMode() and not voicemode.isVoiceMode() then
		local html = {}
			
		local confirming_bridgemode = {
			alert = {
				class = "alert hide",
				id = "confirming-msg-bridgemode"
			}
		}
		local bridgemode_button = {
			button = {
				id = "btn-bridgemode"
			}
		}
		local rebooting_bridgemode = {
			alert = {
			class = "alert hide",
			id = "rebooting-msg-bridgemode"
			}
		}
		local detail_bridgemode = {
			alert = {
			class = "alert alert-info",
			id = "detail-msg-bridgemode"
			}
		}
		html[#html + 1] = ui_helper.createAlertBlock(T"The <strong>Bridged Mode</strong> disables CWMP, Voip service and doesn't create any type of connection. It just connects to the DSLAM and bridges the traffic between a router and the DSLAM itself.", detail_bridgemode)
		html[#html + 1] = ui_helper.createButton(T"Bridged Mode", T"Bridged Mode", "icon-cog", bridgemode_button)
		html[#html + 1] = string.format('<div class="control-group controls">')
		html[#html + 1] = ui_helper.createAlertBlock(T"Switching to <strong>Bridged Mode</strong> and restarting, please wait...", rebooting_bridgemode)
		html[#html + 1] = ui_helper.createAlertBlock(T"Are you sure to switch the modem to <strong>Bridged Mode</strong>? <br />", confirming_bridgemode)
		html[#html + 1] = string.format([[
		<div id="bridgemode-changes" class="hide">
		<div id="bridgemode-confirm" class="btn btn-primary" data-dismiss="modal">%s</div>
			<div id="bridgemode-cancel" class="btn">%s</div>
		</div>
		</div>
		]], T"Confirm", T"Cancel")
		ngx.print(html)
	
	elseif bridgemode.isBridgedMode() then
		local html = {}
		local infomessage = {
			alert = {
			class = "alert",
			}
		}
		local revertbridgemode_button = {
			button = {
                   id = "btn-revertbridgemode"
			}
		}
		local rebooting_revertbridge = {
			alert = {
			class = "alert hide",
			id = "rebooting-msg-revertbridgemode"
			}
		}
		html[#html + 1] = ui_helper.createButton(T"Revert Bridge Mode", T"Revert Bridge Mode", "icon-cog", revertbridgemode_button)
		html[#html + 1] = ui_helper.createAlertBlock(T"Switching to <strong>Routed Mode</strong> and restarting, please wait...", rebooting_revertbridge)
		ngx.print(html)
	end
	
	if not bridgemode.isBridgedMode() and not voicemode.isVoiceMode() then
		local html = {}
		local confirming_voicemode = {
			alert = {
				class = "alert hide",
				id = "confirming-msg-voicemode"
			}
		}
		local voicemode_button = {
			button = {
				id = "btn-voicemode"
			}
		}
		local rebooting_voicemode = {
			alert = {
			class = "alert hide",
			id = "rebooting-msg-voicemode"
			}
		}
		local detail_voicemode = {
			alert = {
			class = "alert alert-info",
			id = "detail-msg-voicemode"
			}
		}
		html[#html + 1] = ui_helper.createAlertBlock(T"The <strong>Voice Mode</strong> disables CWMP and creates a special connection that only permits to use NTP and VOIP services. You need to use a separate router and make a separate PPPoE connection.", detail_voicemode)
		html[#html + 1] = ui_helper.createButton(T"Voice Mode", T"Voice Mode", "icon-cog", voicemode_button)
		html[#html + 1] = string.format('<div class="control-group controls">')
		html[#html + 1] = ui_helper.createAlertBlock(T"Switching to <strong>Voice Mode</strong> and restarting, please wait...", rebooting_voicemode)
		html[#html + 1] = ui_helper.createAlertBlock(T"Are you sure to switch the modem to <strong>Voice Mode</strong>? <br />", confirming_voicemode)
		html[#html + 1] = string.format([[
		<div id="voicemode-changes" class="hide">
		  <div id="voicemode-confirm" class="btn btn-primary" data-dismiss="modal">%s</div>
		  	<div id="voicemode-cancel" class="btn">%s</div>
		  </div>
		</div>
		]], T"Confirm", T"Cancel")
		ngx.print(html)
	elseif voicemode.isVoiceMode() then
		local html = {}
		local infomessage = {
			alert = {
			class = "alert",
			}
		}
		local revertvoicemode_button = {
			button = {
                   id = "btn-revertvoicemode"
			}
		}
		local rebooting_revertvoicemode = {
			alert = {
			class = "alert hide",
			id = "rebooting-msg-revertvoicemode"
			}
		}
		html[#html + 1] = ui_helper.createButton(T"Revert Voice Mode", T"Revert Voice Mode", "icon-cog", revertvoicemode_button)
		html[#html + 1] = ui_helper.createAlertBlock(T"Switching to <strong>Routed Mode</strong> and restarting, please wait...", rebooting_revertvoicemode)
		ngx.print(html)
	end
	ngx.print('</fieldset>');
end
    lp.setpath("/www/snippets/")
    lp.include(tabdata.current.view)
    if not tabdata.current.ajax then
    -- only display if not doing an ajax request

ngx.print('</form>\
</div>\
')
ngx.print("<script type='text/javascript'>");
ngx.print('\
var rebootMsg = \'');  ngx.print(T"Restarting, please wait..."); ngx.print('\';\
$(function() {\
\
	var refreshTimeOut = 5000;\
	var refreshDelay = 3000;\
	var target = $(".modal form").attr("action");\
\
	function wait_for_webserver_running() {\
		$.ajax({ url: "/", timeout: refreshTimeOut })\
		.done(function(data) {\
		document.open("text/html");\
		document.write(data);\
		document.close();\
		})\
		.fail(function() {\
		window.setTimeout(wait_for_webserver_running, refreshDelay);\
		});\
	}\
\
	function wait_for_webserver_down() {\
		$.ajax({ url: target, timeout: refreshTimeOut })\
		.done(function() {\
		window.setTimeout(wait_for_webserver_down, refreshDelay);\
		})\
		.fail(function() {\
		window.setTimeout(wait_for_webserver_running, refreshDelay);\
		});\
	}\
\
	function resetreboot(msg, msg_dst, action) {\
		msg_dst.after(msg);\
		msg.removeClass("hide");\
		msg[0].scrollIntoView();\
		$.post(\
		target,\
		{ action: action, CSRFtoken: $("meta[name=CSRFtoken]").attr("content") },\
		wait_for_webserver_down,\
		"json"\
		);\
		return false;\
	}\
\
	$("#btn-bridgemode").on("click", function() {\
		$("#confirming-msg-bridgemode").removeClass("hide");\
		$("#bridgemode-changes").removeClass("hide");\
	});\
\
	$("#bridgemode-confirm").on("click", function() {\
		$("#confirming-msg-bridgemode").addClass("hide");\
		$("#bridgemode-changes").addClass("hide");\
		$("#btn-bridgemode").addClass("hide");\
		tch.showProgress(rebootMsg);\
		return resetreboot($("#rebooting-msg-bridgemode"), $("#btn-bridgemode"), "BRIDGEMODE");\
	});\
\
	$("#bridgemode-cancel").on("click", function() {\
		$("#confirming-msg-bridgemode").addClass("hide");\
		$("#bridgemode-changes").addClass("hide");\
	});\
\
	$("#btn-revertbridgemode").on("click", function() {\
		$("#infomessage").addClass("hide");\
		tch.showProgress(rebootMsg);\
		return resetreboot($("#rebooting-msg-revertbridgemode"), $("#btn-revertbridgemode"), "REVERTBRIDGEMODE");\
	});\
\
	$("#btn-voicemode").on("click", function() {\
		$("#confirming-msg-voicemode").removeClass("hide");\
		$("#voicemode-changes").removeClass("hide");\
	});\
\
	$("#voicemode-confirm").on("click", function() {\
		$("#confirming-msg-voicemode").addClass("hide");\
		$("#voicemode-changes").addClass("hide");\
		$("#btn-voicemode").addClass("hide");\
		tch.showProgress(rebootMsg);\
		return resetreboot($("#rebooting-msg-voicemode"), $("#btn-voicemode"), "VOICEMODE");\
	});\
\
	$("#voicemode-cancel").on("click", function() {\
		$("#confirming-msg-voicemode").addClass("hide");\
		$("#voicemode-changes").addClass("hide");\
	});\
\
	$("#btn-revertvoicemode").on("click", function() {\
		$("#infomessage").addClass("hide");\
		tch.showProgress(rebootMsg);\
		return resetreboot($("#rebooting-msg-revertvoicemode"), $("#btn-revertvoicemode"), "REVERTVOICEMODE");\
	});\
\
});\
</script>')
ngx.print(ui_helper.createFooter())
end