--pretranslated: do not change this file

-- Enable localization
-- NG-70799
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local lp = require("web.lp")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local dyntab_helper = require("web.dyntab_helper")
local post_helper = require("web.post_helper")

local imh = require("internetmode_helper")

local tabdata = dyntab_helper.process(imh)

local mode_current = tabdata.current.name
local mode_options = tabdata.options

local session = ngx.ctx.session

local wan_ppp_ll_intf = proxy.get("rpc.network.interface.@wan.ppp.ll_intf")
local wan_ppp_over_atm = ""

if wan_ppp_ll_intf and wan_ppp_ll_intf[1].value then
	wan_ppp_ll_intf = wan_ppp_ll_intf[1].value
	wan_ppp_over_atm = proxy.get(string.format("uci.xtm.atmdevice.@%s.", wan_ppp_ll_intf)) ~= nil
else
	wan_ppp_ll_intf = ""
end

local isp_cwmp_known = {
	{"TIM", T"TIM (Italy)"},
	{"Tiscal", T"Tiscali (Italy)"},
	{"Fastweb", T"Fastweb (Italy)"},
	{"Other", T"Generic"},
}

local mapParams = {
	isp_autodetect = "uci.modgui.var.isp_autodetect",
	isp_detected = "uci.modgui.var.isp"
}

local mapValid = {
	isp_autodetect = post_helper.validateBoolean,
	isp_detected = post_helper.getValidateInEnumSelect(isp_cwmp_known),
}

local content = post_helper.handleQuery(mapParams,mapValid)

if not wan_ppp_over_atm then
   for k,v in ipairs(mode_options) do
       if v[1] == "pppoa" then
           table.remove(mode_options, k)
           break
       end
   end
end

if not tabdata.current.ajax then
	-- only display if not doing an ajax request
	
	-- Currently, the only advanced field is the conncection mode.
	-- So if it's not included, there's no need for an advanced button.
	ngx.print(ui_helper.createHeader(T"Internet Access", true, true)); ngx.print('\
	\
	<div class="modal-body update">\
	<form class="form-horizontal" method="post" action="modals/internet-modal.lp">\
	\
	'); ngx.print(ui_helper.createMessages(message_helper.popMessages()))
	
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
	local switch_mon_isp = {
		input = {
            class = "monitor-changes",
        }
    }
	local isp_autodetect_mon_0 = {
      group = {
        class ="monitor-isp_autodetect monitor-0",
      },
    }
	local isp_autodetect_mon_1 = {
      group = {
        class ="monitor-isp_autodetect monitor-1",
      },
    }
	html[#html+1] = '<fieldset id="conn_mode" class="advanced hide">'
	html[#html+1] = '<legend>' .. T"Connection mode" .. '</legend>'
	html[#html+1] = ui_helper.createInputRadio(T"Mode", "newmode", mode_options, mode_current, mode_attributes)
	html[#html+1] = ui_helper.createButton("", T"Switch connection mode", "icon-cog", mode_button)
	html[#html+1] = '</fieldset>'
	--Autodetect cwmp address
	html[#html+1] = '<legend>' .. T"ISP Detection option" .. '</legend>'
	html[#html+1] = ui_helper.createSwitch(T"ISP Autodetect", "isp_autodetect", content["isp_autodetect"], switch_mon_isp)
	html[#html+1] = ui_helper.createInputRadio(T"ISP used", "isp_detected", isp_cwmp_known, content["isp_detected"], isp_autodetect_mon_0)
	html[#html+1] = ui_helper.createLabel(T"ISP Detected", content["isp_detected"],isp_autodetect_mon_1)
	
	ngx.print(html)

end

lp.setpath("/www/snippets/")
lp.include(tabdata.current.view)

if not tabdata.current.ajax then
    -- only display if not doing an ajax request
ngx.print('\
</form>\
</div>\
\
'); ngx.print(ui_helper.createFooter());
end
