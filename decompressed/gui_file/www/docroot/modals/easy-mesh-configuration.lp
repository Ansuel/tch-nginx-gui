--pretranslated: do not change this file
 
  -- Localization
  gettext.textdomain('webui-core')

  local ngx = ngx
  local proxy = require("datamodel")
  local ui_helper = require("web.ui_helper")
  local post_helper = require("web.post_helper")
  local validatePSK = post_helper.validatePSK
  local content_helper = require("web.content_helper")
  local getValidateStringLengthInRange = post_helper.getValidateStringLengthInRange
  local getAndValidation = post_helper.getAndValidation
  local getValidationIfPropInList = post_helper.getValidationIfPropInList
  local validateBoolean = post_helper.validateBoolean
  local getValidateInEnumSelect = post_helper.getValidateInEnumSelect
  local message_helper = require("web.uimessage_helper")
  local match, format = string.match, string.format
  local has_variant, variant_helper = pcall(require, "variant_helper")
  local variantHelper = nil
  if has_variant and variant_helper then
    variantHelper = post_helper.getVariant(variant_helper, "ExtenderPage", "extenderConfig")
  end
  local backhaulDetails = post_helper.getVariantValue(variantHelper, "backhaulDetails")
  local easyMeshButton = post_helper.getVariantValue(variantHelper, "easyMeshButton")
  if easyMeshButton == nil then
    easyMeshButton = true
  end
  local credShow = post_helper.getVariantValue(variantHelper, "credShow")
  if credShow == nil then
    credShow = true
  end
  local fronthaulString = post_helper.getVariantValue(variantHelper, "fronthaulString")
  if fronthaulString == nil then
    fronthaulString = true
  end
  local extenderInfo = post_helper.getVariantValue(variantHelper, "extenderInfo")
  if extenderInfo == nil then
    extenderInfo = true
  end
  local json = nil
  local ok, mod = pcall(require, "dkjson")
  if ok and type(mod) == "table" then
    json = mod
  else
    ok, mod = pcall(require, "cjson")
    if ok and type(mod) == "table" then
      json = mod
    end
  end

  local function safe_json_encode(data)
    if json and type(json.encode) == "function" then
      return json.encode(data)
    end
    if type(data) ~= "table" then
      return tostring(data)
    end
    local parts = {}
    if #data > 0 then
      for _, v in ipairs(data) do
        parts[#parts + 1] = string.format("%q", tostring(v))
      end
      return "[" .. table.concat(parts, ",") .. "]"
    else
      for k, v in pairs(data) do
        parts[#parts + 1] = string.format("%q:%q", tostring(k), tostring(v))
      end
      return "{" .. table.concat(parts, ",") .. "}"
    end
  end

  local ok_em, em_helper = pcall(require, "easymesh_helper")
  if ok_em and em_helper and em_helper.is_supported and not em_helper.is_supported() then
    ngx.print(ui_helper.createHeader(T"EasyMesh", false, true))
    ngx.print(ui_helper.createAlert({ class = "alert-warning" }, T"EasyMesh is not supported on this device."))
    return
  end

  local lp = require("web.lp")
  lp.setpath("/www/snippets/")

  local securityModes = {}
  local raw_modes = proxy.get("uci.multiap.controller.supported_security_modes")
  local APSec_modes = (type(raw_modes) == "table" and raw_modes[1] and raw_modes[1].value) or ""
  APSec_modes:gsub("[^%s]+", function(c)
    if c == "none" then
      securityModes[#securityModes+1] = { c, T(string.untaint(c:gsub("^%l", string.upper)))}
    else
      securityModes[#securityModes+1] = { c, T(string.untaint(string.upper(c)))}
    end
  end)
  if #securityModes == 0 then
    securityModes = {
      { "none", T"None" },
      { "wpa2-psk", T"WPA2-PSK" }
    }
  end

  local backhaulState = ""
  if backhaulDetails then
    local wirelessValues = proxy.get("uci.wireless.wifi-iface.")
    wirelessValues = content_helper.convertResultToObject("uci.wireless.wifi-iface.", wirelessValues)
    for _, intf in ipairs(wirelessValues) do
      if intf.backhaul == "1" then
        backhaulState = intf.state
      end
    end
  end

  local preferredInterface = {
    {"radio_2G,radio_5Gu,radio_5Gl", T"Both"}
  }
  if post_helper.getVariantValue(variantHelper, "frequencySelection") then
    preferredInterface = {
      {"radio_2G", T"2.4GHz"},
      {"radio_5Gu,radio_5Gl", T"5GHz"},
      {"radio_2G,radio_5Gu,radio_5Gl", T"Both"}
    }
  end

  local function getValidateExtraSpaces(value)
    if match(value, "^%s+") or match(value, "%s+$") then
      return nil, T"Leading and trailing whitespaces are not allowed."
    end
    return true
  end

  local getCredentials = content_helper.convertResultToObject("uci.multiap.controller_credentials.", proxy.get("uci.multiap.controller_credentials."))

  local credParamIndex, ap

  local ap_details, guestAP = {}, {}
  local content = {
    controllerMac = "uci.multiap.controller.macaddress",
    agentMac = "uci.multiap.agent.macaddress"
  }
  if post_helper.isFeatureEnabled("bandsteerDisabled" , role) then
    content.ap0_state = "rpc.wireless.ap.@ap0.admin_state"
    content.ap1_state = "rpc.wireless.ap.@ap1.admin_state"
    if proxy.get("uci.wireless.wifi-bandsteer.@bs1.") then
      ap_details = proxy.get("uci.wireless.wifi-ap.")
      ap_details = content_helper.convertResultToObject("uci.wireless.wifi-ap.", ap_details)
      for _, apVal in ipairs(ap_details) do
        if apVal.bandsteer_id == "bs1" then
          ap = match(apVal.paramindex, "@([^%.]+)")
          guestAP[#guestAP + 1] = ap
          content[ap] = "rpc.wireless.ap.@"..ap..".admin_state"
        end
      end
    end
  end
  content_helper.getExactContent(content)

  local mapParams = {
    agentEnable = "uci.multiap.agent.enabled",
    controllerEnable = "uci.multiap.controller.enabled"
  }
  local mapValid = {
    agentEnable = validateBoolean,
    controllerEnable = validateBoolean
  }
  local isGuest = false
  if not backhaulDetails then
    for _, data in pairs(getCredentials) do
      if data.fronthaul == "1" then
        if credShow then
          if data.paramindex == "@cred0" or not credParamIndex then
            credParamIndex = data.paramindex
            mapParams["state" .. credParamIndex] = "uci.multiap.controller_credentials." .. credParamIndex .. ".state"
            mapParams["ssid" .. credParamIndex] = "uci.multiap.controller_credentials." .. credParamIndex .. ".ssid"
            mapParams["securityMode" .. credParamIndex] = "uci.multiap.controller_credentials." .. credParamIndex .. ".security_mode"
            mapParams["password" .. credParamIndex] = "uci.multiap.controller_credentials." .. credParamIndex .. ".wpa_psk_key"
            mapParams["frequency" .. credParamIndex] = "uci.multiap.controller_credentials." .. credParamIndex .. ".frequency_bands"
            mapParams["fronthaul" .. credParamIndex] = "uci.multiap.controller_credentials." .. credParamIndex .. ".fronthaul"
            mapParams["backhaul" .. credParamIndex] = "uci.multiap.controller_credentials." .. credParamIndex .. ".backhaul"

            mapValid["state" .. credParamIndex] = validateBoolean
            mapValid["ssid" .. credParamIndex] = getAndValidation(getValidateStringLengthInRange(1,32),getValidateExtraSpaces)
            mapValid["securityMode" .. credParamIndex] = getValidateInEnumSelect(securityModes)
            mapValid["password" .. credParamIndex] = getValidationIfPropInList(validatePSK, "securityMode".. credParamIndex, {"wpa2-psk", "wpa-wpa2-psk", "wpa3-psk", "wpa2-wpa3-psk"})
            mapValid["frequency" .. credParamIndex] = getValidateInEnumSelect(preferredInterface)
            mapValid["fronthaul" .. credParamIndex] = validateBoolean
            mapValid["backhaul" .. credParamIndex] = validateBoolean
            break
          end
        else
          credParamIndex = data.paramindex
          mapParams["state" .. credParamIndex] = "uci.multiap.controller_credentials." .. credParamIndex .. ".state"
          mapParams["ssid" .. credParamIndex] = "uci.multiap.controller_credentials." .. credParamIndex .. ".ssid"
          mapParams["securityMode" .. credParamIndex] = "uci.multiap.controller_credentials." .. credParamIndex .. ".security_mode"
          mapParams["password" .. credParamIndex] = "uci.multiap.controller_credentials." .. credParamIndex .. ".wpa_psk_key"
          mapParams["frequency" .. credParamIndex] = "uci.multiap.controller_credentials." .. credParamIndex .. ".frequency_bands"
          mapParams["fronthaul" .. credParamIndex] = "uci.multiap.controller_credentials." .. credParamIndex .. ".fronthaul"
          mapParams["backhaul" .. credParamIndex] = "uci.multiap.controller_credentials." .. credParamIndex .. ".backhaul"

          mapValid["state" .. credParamIndex] = validateBoolean
          mapValid["ssid" .. credParamIndex] = getAndValidation(getValidateStringLengthInRange(1,32),getValidateExtraSpaces)
          mapValid["securityMode" .. credParamIndex] = getValidateInEnumSelect(securityModes)
          mapValid["password" .. credParamIndex] = getValidationIfPropInList(validatePSK, "securityMode".. credParamIndex, {"wpa2-psk", "wpa-wpa2-psk", "wpa3-psk", "wpa2-wpa3-psk"})
          mapValid["frequency" .. credParamIndex] = getValidateInEnumSelect(preferredInterface)
          mapValid["fronthaul" .. credParamIndex] = validateBoolean
          mapValid["backhaul" .. credParamIndex] = validateBoolean
        end
      end
    end

    local cond = proxy.get("uci.wifi_conductor.global.multiap_enabled")
    if cond and #cond > 0 and cond[1].value then
      mapParams.wificonductorEnable = "uci.wifi_conductor.global.multiap_enabled"
      mapValid.wificonductorEnable = validateBoolean
    end
    local bs0 = proxy.get("uci.wireless.wifi-bandsteer.bs0.state")
    local bs0_path = "uci.wireless.wifi-bandsteer.bs0.state"
    if not (bs0 and #bs0 > 0 and bs0[1].value) then
      bs0 = proxy.get("uci.wireless.wifi-bandsteer.@bs0.state")
      bs0_path = "uci.wireless.wifi-bandsteer.@bs0.state"
    end
    if bs0 and #bs0 > 0 and bs0[1].value then
      mapParams.wifibandsteerEnable = bs0_path
      mapValid.wifibandsteerEnable = validateBoolean
    end
    local bs1 = proxy.get("uci.wireless.wifi-bandsteer.bs1.state")
    local bs1_path = "uci.wireless.wifi-bandsteer.bs1.state"
    if not (bs1 and #bs1 > 0 and bs1[1].value) then
      bs1 = proxy.get("uci.wireless.wifi-bandsteer.@bs1.state")
      bs1_path = "uci.wireless.wifi-bandsteer.@bs1.state"
    end
    if bs1 and #bs1 > 0 and bs1[1].value then
      isGuest = true
      mapParams.wifiGuestbandsteerEnable = bs1_path
      mapValid.wifiGuestbandsteerEnable = validateBoolean
    end
  else
    for _, data in pairs(getCredentials) do
      if data.backhaul == "1" then
        credParamIndex = data.paramindex
      end
    end

    if credParamIndex then
      mapParams.backHaulssid = "uci.multiap.controller_credentials." .. credParamIndex .. ".ssid"
      mapParams.backHaulSecurityMode = "uci.multiap.controller_credentials." .. credParamIndex .. ".security_mode"
      mapParams.backHaulPassword = "uci.multiap.controller_credentials." .. credParamIndex .. ".wpa_psk_key"
      mapParams.controllerEnable = "uci.multiap.controller.enabled"
      mapParams.backHaulFrequency = "uci.multiap.controller_credentials." .. credParamIndex .. ".frequency_bands"

      mapValid.backHaulssid = getAndValidation(getValidateStringLengthInRange(1,32),getValidateExtraSpaces)
      mapValid.backHaulSecurityMode = getValidateInEnumSelect(securityModes)
      mapValid.backHaulPassword = getValidationIfPropInList(validatePSK,"backHaulSecurityMode", {"wpa2-psk", "wpa-wpa2-psk"})
      mapValid.controllerEnable = validateBoolean
      mapValid.backHaulFrequency = getValidateInEnumSelect(preferredInterface)
    end
  end

  local params, helpmsg = post_helper.handleQuery(mapParams, mapValid)

  ngx.print(ui_helper.createHeader(T"EasyMesh", false, true))
  ngx.print('\
<div class="modal-body update">\
')
  lp.include("tabs-easyMesh.lp")
  ngx.print('\
<form class="form-horizontal" method="post" action="modals/easy-mesh-configuration.lp">\
  <div class="alert alert-info" style="margin-bottom: 20px;">\
    <i class="icon-sitemap" style="margin-right: 6px;"></i>\
    <strong>EasyMesh:</strong> ')
  ngx.print(T"EasyMesh standard enables a seamless, synchronized Wi-Fi mesh network between this gateway and compatible extenders.")
  ngx.print('\
  </div>\
')
  ngx.print(ui_helper.createMessages(message_helper.popMessages()))
  ngx.print('\
  <fieldset id="easy-mesh-configuration-tab">\
    <legend>')
  ngx.print(T"General")
  ngx.print('</legend>\
')

      local ssidclass = {
        input = {
          pattern = "[!-~][ -~]{0,30}[!-~]",
          maxlength = "32",
          class = "span4"
        }
      }

      local pskclass = {
        group = {
          class = "monitor-security monitor-wpa-psk monitor-wpa2-psk monitor-wpa-wpa2-psk monitor-wpa3-psk monitor-wpa2-wpa3-psk",
        },
        input = {
          class= "span4",
          maxlength = "63"
        }
      }

      local controllerClass = {
        span = {
          id = "controllermac"
        }
      }

      local agentClass = {
        span = {
          id = "agentmac"
        }
      }

      local html = {}
      if extenderInfo then
        if backhaulDetails and backhaulState ~= "0" then
          html[#html + 1] = ui_helper.createLabel(T"Backhaul SSID", params.backHaulssid, ssidclass)
          html[#html + 1] = ui_helper.createLabel(T"Backhaul Password", params.backHaulPassword, pskclass)
          html[#html + 1] = ui_helper.createLabel(T"Security Mode", params.backHaulSecurityMode)
        elseif easyMeshButton then
          html[#html + 1] = ui_helper.createSwitch(T"EasyMesh Services", "easyMeshEnable", ((params.agentEnable == "1" and params.controllerEnable == "1") and "1" or "0"))
          ngx.print(html)
          html = {}
          ngx.print('\
          <div class="control-group" style="margin-top: -8px; margin-bottom: 20px;">\
            <div class="controls">\
              <span class="help-block" style="font-size: 12px; color: #777;">\
                ')
          ngx.print(T"Enable EasyMesh controller and agent to manage synchronized Wi-Fi extenders.")
          ngx.print('\
              </span>\
            </div>\
          </div>\
          <div id="fronthaul-config-wrap">\
          ')
          for _, data in pairs(getCredentials) do
            if data.fronthaul == "1" then
              if (credShow and data.paramindex == "@cred0") or not credShow then
                local cIndex = data.paramindex
                local fTitle = fronthaulString and T"Fronthaul Configuration" or string.upper(string.sub(cIndex, 2, -1))
                ngx.print('\
                <legend>' .. fTitle .. '</legend>\
                <div class="control-group" style="margin-top: -8px; margin-bottom: 15px;">\
                  <div class="controls">\
                    <span class="help-block" style="font-size: 12px; color: #777;">\
                      ' .. T"Network parameters propagated by EasyMesh to all connected extenders." .. '\
                    </span>\
                  </div>\
                </div>\
                ')
                if post_helper.getVariantValue(variantHelper, "credStatusSwitch") then
                  html[#html + 1] = ui_helper.createSwitch(T"State", "state" .. cIndex, params["state" .. cIndex])
                end
                html[#html + 1] = ui_helper.createInputText(T"SSID", "ssid" .. cIndex, params["ssid" .. cIndex], ssidclass, helpmsg["ssid" .. cIndex])
                html[#html + 1] = ui_helper.createInputText(T"Password", "password" .. cIndex, params["password" .. cIndex], pskclass, helpmsg["password" .. cIndex])
                html[#html + 1] = ui_helper.createInputSelect(T"Security Mode", "securityMode" .. cIndex, securityModes, params["securityMode" .. cIndex])
                html[#html + 1] = ui_helper.createInputSelect(T"Preferred Interface", "frequency" .. cIndex, preferredInterface, params["frequency" .. cIndex])
                if post_helper.getVariantValue(variantHelper, "haulSwitch") then
                  html[#html + 1] = ui_helper.createSwitch(T"Fronthaul", "fronthaul" .. cIndex, params["fronthaul" .. cIndex])
                  html[#html + 1] = ui_helper.createSwitch(T"Backhaul", "backhaul" .. cIndex, params["backhaul" .. cIndex])
                end
                if credShow then
                  break
                end
              end
            end
          end
          ngx.print(html)
          html = {}
          ngx.print('</div>')
        end
      elseif easyMeshButton then
        html[#html + 1] = ui_helper.createSwitch(T"EasyMesh Agent", "easyMeshEnable", (params.agentEnable == "1" and "1" or "0"))
      end
      if post_helper.getVariantValue(variantHelper, "controllerAgentMacAddress") then
        html[#html + 1] = ui_helper.createLabel(T"EasyMesh controller MAC Address", content.controllerMac, controllerClass)
        html[#html + 1] = ui_helper.createLabel(T"EasyMesh Agent MAC Address", content.agentMac, agentClass)
      end

      local agent_enable_class = {
        group = {
          class = "hide"
        },
        input = {
          class = "span4",
          id = "agentEnable"
        }
      }
      html[#html+1] = ui_helper.createInputText(T"", "agentEnable", params.agentEnable, agent_enable_class)

      local controller_enable_class = {
        group = {
          class = "hide"
        },
        input = {
          class = "span4",
          id = "controllerEnable"
        }
      }
      html[#html+1] = ui_helper.createInputText(T"", "controllerEnable", params.controllerEnable, controller_enable_class)
      local wifibandsteer_enable_class = {
        group = {
          class = "hide"
        },
        input = {
          class = "span4",
          id = "wifibandsteerEnable"
        },
      }
      local wifiguestbandsteer_enable_class = {
        group = {
          class = "hide"
        },
        input = {
          class = "span4",
          id = "wifiGuestbandsteerEnable"
        },
      }
      local wificonductor_enable_class = {
        group = {
          class = "hide"
        },
        input = {
          class = "span4",
          id = "wificonductorEnable"
        },
      }
      if easyMeshButton then
        if mapParams.wifibandsteerEnable then
          html[#html+1] = ui_helper.createInputText(T"", "wifibandsteerEnable", params.wifibandsteerEnable, wifibandsteer_enable_class)
        end
        if isGuest and mapParams.wifiGuestbandsteerEnable then
          html[#html+1] = ui_helper.createInputText(T"", "wifiGuestbandsteerEnable", params.wifiGuestbandsteerEnable, wifiguestbandsteer_enable_class)
        end
      end

      if mapParams.wificonductorEnable then
        html[#html+1] = ui_helper.createInputText(T"", "wificonductorEnable", params.wificonductorEnable, wificonductor_enable_class)
      end
      ngx.print(html)
      ngx.print('\
  </fieldset>\
</form>\
</div>\
')
      ngx.print(ui_helper.createFooter())
      ngx.print('\
<script>\
  var multiapAgent = "');  ngx.print(params.agentEnable); ngx.print('";\
  var multiapContr = "');  ngx.print(params.controllerEnable); ngx.print('";\
  var ap0_state =  "');  ngx.print(post_helper.isFeatureEnabled("bandsteerDisabled" , role) and content.ap0_state or ""); ngx.print('";\
  var ap1_state =  "');  ngx.print(post_helper.isFeatureEnabled("bandsteerDisabled" , role) and content.ap1_state or ""); ngx.print('";\
  var confirmPopup = "');  ngx.print(post_helper.getVariantValue(variantHelper, "easyMeshConfirmPopup")); ngx.print('";\
  var easyMeshDisableMessage = "');  ngx.print(T'EasyMesh is disabled.<br> You can safely enable Bandsteering, if needed'); ngx.print('";\
  var easyMeshEnableMessage = "');  ngx.print(T'EasyMesh is enabled.<br> This action will disable Bandsteering'); ngx.print('";\
  var agentList = "');  ngx.print(T'Agent List'); ngx.print('";\
  var extenderInfo = "');  ngx.print(T'Extender Info'); ngx.print('";\
  var devicesList = "');  ngx.print(T'WiFi Devices'); ngx.print('";\
  var disableTitle = "');  ngx.print(T'Disable EasyMesh'); ngx.print('";\
  var enableTitle = "');  ngx.print(T'Enable EasyMesh'); ngx.print('";\
  var content = ');  ngx.print(safe_json_encode(content) ); ngx.print(';\
  var guestAP = ');  ngx.print(safe_json_encode(guestAP) ); ngx.print(';\
  var isGuest = ');  ngx.print(isGuest); ngx.print(';\
  var bandsteerDisabled = ');  ngx.print(post_helper.isFeatureEnabled("bandsteerDisabled" , role)); ngx.print(';\
</script>\
<script src="/js/easy-mesh-configuration.js"></script>\
'); 
