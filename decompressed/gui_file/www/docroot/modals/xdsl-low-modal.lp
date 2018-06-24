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

local bridgedmode = require("bridgedmode_helper")
local voicemode = require("voicemode_helper")

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
	  proxy.set("rpc.system.refreshdriver", "1")
      proxy.apply()
    end
end

local content = {
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

local driver_option = nil

if content.dsl0_xdsl_FirmwareVersion:match(".*H042") or content.dsl0_xdsl_FirmwareVersion:match(".*H042") then

	tinsert(driver_option, { "B2pvbH042l.d26r", 'B2pvbH042l.d26r (DSL-AC87VG_v1.00.10)'})
	tinsert(driver_option, { "A2pvbH042n.d26r", 'A2pvbH042n.d26r (Netgear D7000)'})
	tinsert(driver_option, { "A2pvbH042j2.d26r", 'A2pvbH042j2.d26r (Asus DSL-AC88U) ' .. 'Best value'})
	tinsert(driver_option, { "A2pvbH042o.d26r", 'A2pvbH042o.d26r (TG799VAC Xtream Fastweb)'})
	tinsert(driver_option, { "A2pvbH042r.d26r", 'A2pvbH042r.d26r (AGTEF_1.0.3)'})
	tinsert(driver_option, { "B2pvbH042s.d26r", 'B2pvbH042s.d26r (Archer_VR2800vV1_1.2.0_0.9.1)'})
	tinsert(driver_option, { "A2pvbH042u.d26r", 'A2pvbH042u.d26r (AGTEF_1.0.4)'})
	
	if tonumber(content.marketing_version) >= 17.3 then
		tinsert(driver_option, { "A2pvfbH043b.d26r", 'A2pvfbH043b.d26r (New FastGate Fastweb)'})
		tinsert(driver_option, { "B2pvfbH043e.d26r", 'B2pvfbH043e.d26r (DSL-AC87VG_v1.00.13)'})
		--table.insert(driver_option,{ "A2pvfbH043e.d26r", 'A2pvfbH043e.d26r (Zyxel 8823)'}) --Annex b???
		--table.insert(driver_option,{ "A2pvfbH043f.d26r", 'A2pvfbH043f.d26r (DSL AC88U) ' .. T'Less Ping'}) --Missing
		tinsert(driver_option, { "B2pvfbH043g.d26r", 'B2pvfbH043g.d26r (DSL-AC68VG_v5.00.04)'})
		tinsert(driver_option, { "A2pvfbH043g.d26r", 'A2pvfbH043g.d26r (TG800 Vbant-s)'})
		tinsert(driver_option, { "B2pvfbH043i1.d26r", 'B2pvfbH043i1.d26r (VMG8823-B60B_5.13)'})
		tinsert(driver_option, { "A2pvfbH043k.d26r", 'A2pvfbH043k.d26r (AGTEF_1.1.0)'})
		tinsert(driver_option, { "B2pvfbH043k.d26r", 'B2pvfbH043k.d26r (DSL-AC88U-B_v1.10.05)'})
		tinsert(driver_option, { "A2pvfbH043o.d26r", 'A2pvfbH043o.d26r (DSL88U) ' .. T'Beta Firmware'})
	end
end


local driver_Params = {
  driver_ver = "uci.env.var.driver_version",
  ds10_sra = "uci.xdsl.xdsl.@dsl0.sra",
  ds10_bitswap = "uci.xdsl.xdsl.@dsl0.bitswap",
}

local driver_valid = {
  driver_ver = post_helper.getValidateInEnumSelect(driver_option),
  ds10_sra = post_helper.validateBoolean,
  ds10_bitswap = post_helper.validateBoolean,
}

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
      local html = {}
      html[#html + 1] = ui_helper.createLight(T"Status", nil, state_map[untaint(content.dsl0_enabled)], { light = { class = light_map[untaint(content.dsl0_enabled)] } })
      html[#html + 1] = ui_helper.createLabel(T"Dslam Chipset",content.dslam_chipset, span5 )
	  if content.dslam_version_raw:sub(0,2) == "0x" then
		html[#html + 1] = ui_helper.createLabel(T"Dslam Firmware Version",format("%s ( %s )", content.dslam_version , content.dslam_version_raw) , span5 )
	  elseif content.dslam_version_raw == "" then
		html[#html + 1] = ui_helper.createLabel(T"Dslam Firmware Version",T"Can't recover dslam version." , span5 )
	  else
		html[#html + 1] = ui_helper.createLabel(T"Dslam Firmware Version",format(T"Invalid version, can't convert. Raw value: %s", content.dslam_version_raw) , span5 )
	  end
	  html[#html + 1] = ui_helper.createLabel(T"Firmware Version",content.dsl0_xdsl_FirmwareVersion, span5 )
	  if not driver_option then
		html[#html + 1] = ui_helper.createLabel(T"Driver Version",T"We don't have any firmware for this modem, please report them to the github page. ", span5 )
	  elseif not bridgedmode.isBridgedMode() and not voicemode.isVoiceMode() then
		html[#html + 1] = ui_helper.createInputSelect(T"Driver Version", "driver_ver", driver_option, driver_content["driver_ver"])
	  else
		html[#html + 1] = ui_helper.createLabel(T"Driver Version",T"In this mode, the script you cant download the driver. Download and apply it manually. Look in the forum repository for more info. ", span5 )
	  end
	  html[#html + 1] = ui_helper.createSwitch(T"SRA", "ds10_sra", driver_content["ds10_sra"])
	  html[#html + 1] = ui_helper.createSwitch(T"Bitswap", "ds10_bitswap", driver_content["ds10_bitswap"])
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