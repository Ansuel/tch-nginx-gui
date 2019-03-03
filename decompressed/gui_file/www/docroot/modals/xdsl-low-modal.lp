--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local lp = require("web.lp")
local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local tinsert,format,sub,match,untaint = table.insert,string.format, string.sub, string.match, string.untaint

local all_modes = {"adsl2", "adsl2annexl", "adsl2annexm", "adsl2plus", "gdmt", "glite", "t1413", "vdsl2" }

table.sort(all_modes, function(a,b)
         return a<b
      end)

function split(x, sep)
        local sep, fields = sep or ":", {}
        local pattern = format("([^%s]+)", sep)
        x:gsub(pattern, function(c) fields[#fields+1] = c end)
        return fields
end

local modes_content = content_helper.getMatchedContent ("uci.xdsl.xdsl.@dsl0.multimode.")

if ngx.var.request_method == "POST" then
    local vars = ngx.req.get_post_args()
    if vars["action"] == "SAVE" then
      local mode2prog = {}
      for _, v in pairs(all_modes) do
         mode2prog[v] = {prog = 0, found = 0 }
      end
      if type(vars["modes"])=="table" then
          for _, x in pairs(vars["modes"]) do
            for k,_ in pairs(mode2prog) do
               if k == x then
                  mode2prog[format("%s",k)].prog = 1
               end
            end
          end
      else
          for k,_ in pairs(mode2prog) do
             if k == vars["modes"] then
                mode2prog[format("%s",k)].prog = 1
             end
          end
      end
      for _,v in pairs(modes_content) do
         local found = 0
          for k,w in pairs(mode2prog) do
            if v.value == k then
               mode2prog[format("%s",k)].found = v.path
               found = 1
            end
          end
          if found == 0 then
             mode2prog[format("%s",v.path)].found = v.path
             mode2prog[format("%s",v.path)].prog = 0
          end
      end
      for k,v in pairs(mode2prog) do
         if v.prog == 1 and v.found == 0 then
               local addvalue = proxy.add("uci.xdsl.xdsl.@dsl0.multimode.")
               proxy.set("uci.xdsl.xdsl.@dsl0.multimode.@" .. addvalue .. ".value",k)
         elseif v.prog == 0 and v.found then
               local clean = proxy.del(v.found)
         end
      end
	  proxy.set("rpc.system.modgui.utility.refreshdriver", "1")
      proxy.apply()
    end
end

local content = {
	dsl0_status 					= "sys.class.xdsl.@line0.Status",
    dsl0_mode 					    = "rpc.xdslctl.DslMode",
    dsl0_profile 					= "rpc.xdslctl.DslProfile",
    dsl0_port 					= "rpc.xdslctl.DslamPort",
    dsl0_enabled                    = "uci.xdsl.xdsl.@dsl0.enabled",
    dsl0_eoc_vendor_id              = "uci.xdsl.xdsl.@dsl0.eoc_vendor_id",
    dsl0_eoc_serial_number          = "uci.xdsl.xdsl.@dsl0.eoc_serial_number",
    dsl0_handshake_switch_timeout   = "uci.xdsl.xdsl.@dsl0.handshake_switch_timeout",
    dsl0_demod_cap_value            = "uci.xdsl.xdsl.@dsl0.demod_cap_value",
    dsl0_demod_cap_mask             = "uci.xdsl.xdsl.@dsl0.demod_cap_mask",
    dsl0_demod_cap2_value           = "uci.xdsl.xdsl.@dsl0.demod_cap2_value",
    dsl0_demod_cap2_mask            = "uci.xdsl.xdsl.@dsl0.demod_cap2_mask",
    dsl0_aux_features_value         = "uci.xdsl.xdsl.@dsl0.aux_features_value",
    dsl0_aux_features_mask          = "uci.xdsl.xdsl.@dsl0.aux_features_mask",
    dsl0_vdsl_cfg_flags_value       = "uci.xdsl.xdsl.@dsl0.vdsl_cfg_flags_value",
    dsl0_vdsl_cfg_flags_mask        = "uci.xdsl.xdsl.@dsl0.vdsl_cfg_flags_mask",
    dsl0_xdsl_cfg1_value            = "uci.xdsl.xdsl.@dsl0.xdsl_cfg1_value",
    dsl0_xdsl_cfg1_mask             = "uci.xdsl.xdsl.@dsl0.xdsl_cfg1_mask",
    dsl0_xdsl_FirmwareVersion       = "sys.class.xdsl.@line0.FirmwareVersion",
	marketing_version				= "uci.version.version.@version[0].marketing_version",
	dslam_chipset 					= "rpc.xdslctl.DslamChipset",
	dslam_version 					= "rpc.xdslctl.DslamVersion",
    dslam_version_raw				= "rpc.xdslctl.DslamVersionRaw"
}

content_helper.getExactContent(content)

if content.dslam_chipset:match("BDCM") then
	content.dslam_chipset = "Broadcom" .. " ( " .. content.dslam_chipset .. " )"
elseif content.dslam_chipset:match("IFTN") then
	content.dslam_chipset = "Infineon" .. " ( " .. content.dslam_chipset .. " )"
end

local state_map = {
    ["0"] = T"Disabled",
    ["1"] = T"Enabled",
}

local light_map = {
    ["0"] = "off",
    ["1"] = "green",
}

table.sort(modes_content, function(a,b)
         return match(a.path, "@(%d)")< match(b.path, "@(%d)")
      end)
local mode_list = nil
for _, v in pairs (modes_content) do
  if not mode_list then
      mode_list = format("%s",v.value)
  else
      mode_list = format("%s, %s",mode_list,v.value)
  end
end

local profiles_content = content_helper.getMatchedContent ("uci.xdsl.xdsl.@dsl0.profile.")
table.sort(profiles_content, function(a,b)
         return match(a.path, "@(%d)")< match(b.path, "@(%d)")
      end)
local profile_list = nil
for _, v in pairs (profiles_content) do
  if not profile_list then
      profile_list = format("%s",v.value)
  else
      profile_list = format("%s, %s",profile_list,v.value)
  end
end

local driver_option = {}

local driver_Params = {
  ds10_sra = "uci.xdsl.xdsl.@dsl0.sra",
  ds10_bitswap = "uci.xdsl.xdsl.@dsl0.bitswap",
  ds10_snr = "uci.xdsl.xdsl.@dsl0.snr",
}

local driver_valid = {
  ds10_sra = post_helper.validateBoolean,
  ds10_bitswap = post_helper.validateBoolean,
  ds10_snr = post_helper.getValidateNumberInRange(0,65535),
}

if content.dsl0_xdsl_FirmwareVersion:match(".*H045") or content.dsl0_xdsl_FirmwareVersion:match(".*H043") or content.dsl0_xdsl_FirmwareVersion:match(".*H042") then
	tinsert(driver_option, { "B2pvbH042l", 'B2pvbH042l (Asus DSL-AC87VG v1.00.10)'})
    tinsert(driver_option, { "B2pvbH042j2", 'B2pvbH042j2 (Inteno)'})
    tinsert(driver_option, { "B2pvbH042s", 'B2pvbH042s (Archer_VR2800v V1 1.2.0_0.9.1)'})
	tinsert(driver_option, { "A2pvbH042j2", 'A2pvbH042j2 (Asus DSL-AC88U)'})
    tinsert(driver_option, { "A2pvbH042n", 'A2pvbH042n (Netgear D7000)'})
	tinsert(driver_option, { "A2pvbH042o", 'A2pvbH042o (TG799VAC Xtream Fastweb)'})
	tinsert(driver_option, { "A2pvbH042r", 'A2pvbH042r (AGTEF_1.0.3)'})
	tinsert(driver_option, { "A2pvbH042u", 'A2pvbH042u (AGTEF_1.0.4)'})
	
	if tonumber(content.marketing_version:sub(1,4)) >= 17.2 then
        tinsert(driver_option, { "B2pvfbH043d1", 'B2pvfbH043d1 (FRITZ!Box 7581 6.54)'})
		tinsert(driver_option, { "B2pvfbH043e", 'B2pvfbH043e (Asus DSL-AC87VG_v1.00.13)'})
		tinsert(driver_option, { "B2pvfbH043g", 'B2pvfbH043g (Asus DSL-AC68VG v5.00.04)'})
        tinsert(driver_option, { "B2pvfbH043i1", 'B2pvfbH043i1 (VMG8823-B60B 5.13)'})
        tinsert(driver_option, { "B2pvfbH043k", 'B2pvfbH043k (Asus DSL-AC88U-B v1.10.05)'})
        tinsert(driver_option, { "B2pvfbH043q", 'B2pvfbH043q (FRITZ!Box 7582 7.01/Asus DSL-AC88U-B v1.10.06_591)'})
        tinsert(driver_option, { "A2pvfbH043b", 'A2pvfbH043b (New FastGate Fastweb)'})
        tinsert(driver_option, { "A2pvfbH043d1", 'A2pvfbH043d1 (FRITZ!Box 7581 6.54)'})
        --table.insert(driver_option,{ "A2pvfbH043e", 'A2pvfbH043e (Zyxel 8823)'}) --Annex b???
        --table.insert(driver_option,{ "A2pvfbH043f", 'A2pvfbH043f (DSL AC88U) ' .. T'Less Ping'}) --Missing
		tinsert(driver_option, { "A2pvfbH043g", 'A2pvfbH043g (TG800 VBANT-S)'})
        tinsert(driver_option, { "A2pvfbH043h", 'A2pvfbH043h (Inteno DG400PRIME)'})
        tinsert(driver_option, { "A2pvfbH043i", 'A2pvfbH043i (Inteno)'})
        tinsert(driver_option, { "A2pvfbH043i2", 'A2pvfbH043i2 (Zyxel C3000Z)'})
        tinsert(driver_option, { "A2pvfbH043j2", 'A2pvfbH043j2 (FRITZ!Box 7582 7.01 Backup)'})
		tinsert(driver_option, { "A2pvfbH043k", 'A2pvfbH043k (AGTEF_1.1.0)'})
		tinsert(driver_option, { "A2pvfbH043o", 'A2pvfbH043o (Asus DSL-AC88U v1.10.06_561)'})
        tinsert(driver_option, { "A2pvfbH043q", 'A2pvfbH043q (FRITZ!Box 7582 7.01/Asus DSL-AC88U v1.10.06_585)'})
        tinsert(driver_option, { "A2pvfbH045k", 'A2pvfbH045k (Inteno)'})
	end
	
	driver_Params.driver_ver = "uci.modgui.var.driver_version"
	driver_valid.driver_ver = post_helper.getValidateInEnumSelect(driver_option)
elseif content.dsl0_xdsl_FirmwareVersion:match(".*F039") then
    tinsert(driver_option, { "B2pv6F039k", 'B2pv6F039k (TP-Link Archer VR900vV1)'})
    tinsert(driver_option, { "B2pv6F039v", 'B2pv6F039v (789vacV2 UNO.uk 17.1/Tiscali 16.3 Backup)'})
    tinsert(driver_option, { "A2pv6F038f2", 'A2pv6F038f2 (Comtrend VR-3032u)'})
    tinsert(driver_option, { "A2pv6F039e", 'A2pv6F039e (Huawei HG635)'})
    tinsert(driver_option, { "A2pv6F039f1", 'A2pv6F039f1 (Indeno D301)'})
    tinsert(driver_option, { "A2pv6F039m1", 'A2pv6F039m1 (Sky NR701-NR801)'})
    tinsert(driver_option, { "A2pv6F039o1", 'A2pv6F039o1 (Telsra TG799vac)'})
    tinsert(driver_option, { "A2pv6F039u", 'A2pv6F039u (Netgear D6220 v1.0.0.48/Sercomm VD625)'})
    tinsert(driver_option, { "A2pv6F039v", 'A2pv6F039v (SmartRG sr516ac/Tp-link Archer VR600V1)'})
    tinsert(driver_option, { "A2pv6F039v2", 'A2pv6F039v2 (789vacV2 UNO.uk 17.1/Tiscali 16.3)'})
    tinsert(driver_option, { "A2pv6F039v4", 'A2pv6F039v4 (Inteno D301)'})
    tinsert(driver_option, { "A2pv6F039x1", 'A2pv6F039x1 (Zyxel VMG3926)'})
    tinsert(driver_option, { "A2pv6F039x5", 'A2pv6F039x5 (SmartRG SR505N/SR515AC 2.6.1.9)'})
    tinsert(driver_option, { "A2pv6F039x6", 'A2pv6F039x6 (Zyxel VMG3926-B10B)'})

    driver_Params.driver_ver = "uci.modgui.var.driver_version"
    driver_valid.driver_ver = post_helper.getValidateInEnumSelect(driver_option)
end


local driver_content, helpmsg = post_helper.handleQuery(driver_Params, driver_valid)

  ngx.print('\
\
');  ngx.print(ui_helper.createHeader(T"xDSL Details", false, false))   ngx.print('\
<div class="modal-body update">\
');  
ngx.print(ui_helper.createMessages(message_helper.popMessages()))


  ngx.print('\
<fieldset>\
  <legend>');  ngx.print( T"Core Settings" ); ngx.print('</legend>\
    <form class="form-horizontal" method="post" action="modals/xdsl-low-modal.lp">\
    ');  
      local span5 = { span = { class = "span5" } }
	  local alertinfo = { alert = { class = "alert-info" } }
      local html = {}
      html[#html + 1] = ui_helper.createLight(T"Status", nil, state_map[untaint(content.dsl0_enabled)], { light = { class = light_map[untaint(content.dsl0_enabled)] } })
	  html[#html + 1] = ui_helper.createLabel(T"DSL Connection Status", content.dsl0_status, span5 )
	  if ( content.dsl0_status == "Up" ) then
        html[#html + 1] = ui_helper.createLabel(T"DSL Mode", content.dsl0_mode, span5 )
        if(content.dsl0_profile ~= "Not Found") then
            html[#html + 1] = ui_helper.createLabel(T"VDSL Profile", content.dsl0_profile, span5 )
            html[#html + 1] = ui_helper.createLabel(T"VDSL DSLAM Port", content.dsl0_port, span5 )
        end
		html[#html + 1] = ui_helper.createLabel(T"DSLAM Chipset",content.dslam_chipset, span5 )
		if content.dslam_version_raw:sub(0,2) == "0x" then
			html[#html + 1] = ui_helper.createLabel(T"DSLAM Firmware",format("%s ( %s )", content.dslam_version , content.dslam_version_raw) , span5 )
		elseif content.dslam_version_raw == "" then
			html[#html + 1] = ui_helper.createLabel(T"DSLAM Firmware",T"Can't recover DSLAM version." , span5 )
		else
			html[#html + 1] = ui_helper.createLabel(T"DSLAM Firmware",format(T"Invalid version, can't convert. Raw value: %s", content.dslam_version_raw) , span5 )
		end
	  end
	  html[#html + 1] = ui_helper.createLabel(T"Firmware Version",content.dsl0_xdsl_FirmwareVersion, span5 )
	  if not driver_Params.driver_ver then
		html[#html + 1] = ui_helper.createLabel(T"Driver Version",T"We don't have any firmware for this modem, please report them to the github page. ", span5 )
	  else
		html[#html + 1] = ui_helper.createInputSelect(T"Driver Version", "driver_ver", driver_option, driver_content["driver_ver"])
	  end
	  html[#html + 1] = ui_helper.createSwitch(T"SRA", "ds10_sra", driver_content["ds10_sra"])
	  html[#html + 1] = ui_helper.createSwitch(T"Bitswap", "ds10_bitswap", driver_content["ds10_bitswap"])
	  html[#html + 1] = ui_helper.createAlertBlock(T"Change the SNR margin to increase stability or performance when in “ADSL Mode”. Changing this value in “VDSL Mode” won’t have any effect.", alertinfo)
	  html[#html + 1] = ui_helper.createInputText(T"SNR", "ds10_snr", driver_content["ds10_snr"])
      html[#html + 1] = ui_helper.createLabel(T"EOC Vendor ID",content.dsl0_eoc_vendor_id, span5 )
      html[#html + 1] = ui_helper.createLabel(T"EOC Serial Number",content.dsl0_eoc_serial_number, span5 )
      html[#html + 1] = [[<div class="control-group"><label class="control-label">]]
      html[#html + 1] = T"Modes"
      html[#html + 1] = [[</label><div class="controls"><select multiple class="form-control" name="modes">]]
      for i=1,#all_modes do
          local selected = ""
          for _, w in pairs (modes_content) do
                if all_modes[i]  == w.value then
                  selected = "selected"
                end
          end
          html[#html + 1] = format("<option name=\"%s\" %s>%s</option>",all_modes[i],selected,all_modes[i])
      end
      html[#html + 1] = [[  </select></div></div>]]
      html[#html + 1] = ui_helper.createLabel(T"Profiles",profile_list or "",span5 )
      html[#html + 1] = ui_helper.createLabel(T"HS Switch Timeout",content.dsl0_handshake_switch_timeout, span5 )
      html[#html + 1] = ui_helper.createLabel(T"Demod Cap Value",content.dsl0_demod_cap_value, span5 )
      html[#html + 1] = ui_helper.createLabel(T"Demod Cap Mask",content.dsl0_demod_cap_mask, span5 )
      html[#html + 1] = ui_helper.createLabel(T"2nd Demod Cap Value",content.dsl0_demod_cap2_value, span5 )
      html[#html + 1] = ui_helper.createLabel(T"2nd Demod Cap Mask",content.dsl0_demod_cap2_mask, span5 )
      html[#html + 1] = ui_helper.createLabel(T"Aux Features Value",content.dsl0_aux_features_value, span5 )
      html[#html + 1] = ui_helper.createLabel(T"Aux Features Mask",content.dsl0_aux_features_mask, span5 )
      html[#html + 1] = ui_helper.createLabel(T"VDSL Flags Value",content.dsl0_vdsl_cfg_flags_value, span5 )
      html[#html + 1] = ui_helper.createLabel(T"VDSL Flags Mask",content.dsl0_vdsl_cfg_flags_mask, span5 )
      html[#html + 1] = ui_helper.createLabel(T"Phy Extra Value",content.dsl0_xdsl_cfg1_value, span5 )
      html[#html + 1] = ui_helper.createLabel(T"Phy Extra Mask",content.dsl0_xdsl_cfg1_mask, span5 )
      ngx.print(html)
      ngx.print('\
	</form>\
  </fieldset>\
</div>\
');   ngx.print(ui_helper.createFooter())  ngx.print('\
');