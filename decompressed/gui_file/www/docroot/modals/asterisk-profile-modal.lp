<%
-- Localization
gettext.textdomain('webui-voice')
-----------------------------------------------------------------------------------------
local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local table, ipairs = table, ipairs
local proxy = require("datamodel")
local message_helper = require("web.uimessage_helper")
local prod_friendly_name = proxy.get("uci.env.var.prod_friendly_name")
-- Shortcuts to validation helpers to make lines shorter
local gVIPIL = post_helper.getValidationIfPropInList
local gVIES = post_helper.getValidateInEnumSelect
local vB = post_helper.validateBoolean
local vNES = post_helper.validateNonEmptyString
local vSIP = post_helper.validateStringIsPort
local vSIPR = post_helper.validateStringIsPortRange
local gVP = post_helper.getValidationPassword
local gVSIDIP = post_helper.getValidateStringIsDeviceIPv4
local vSIIP6 = post_helper.validateStringIsIPv6
local gAV = post_helper.getAndValidation
local gOrV = post_helper.getOrValidation
local vQTN = post_helper.validateQTN
local gOV = post_helper.getOptionalValidation
local vSIDN = post_helper.validateStringIsDomainName
local vSIIP = post_helper.validateStringIsIP
local vSIM = post_helper.validateStringIsMAC
-----------------------------------------------------------------------------------------
local mapValid = {	
	cache_record_files = vB,
	dontwarn = vB,
	dumpcore = vB,
	nocolor = vB,
	live_dangerously = vB,
	transcode_via_sln = vB,
	transmit_silence_during_record = vB,
	make_outgoing_calls = vB,
	register = vB,
	ring = vB,
	can_call = vB,
	canreinvite = vB,
	FirstName = vB,
	LastName = vB
}
-----------------------------------------------------------------------------------------
local mapParams = {
  	cache_record_files = "uci.pbx.asterisk.@asterisk.ethernet.cache_record_files",
  	debug1 = "uci.pbx.asterisk.@asterisk.debug",
  	verbose	= "uci.pbx.asterisk.@asterisk.verbose",
 	dontwarn = "uci.pbx.asterisk.@asterisk.dontwarn",
  	dumpcore = "uci.pbx.asterisk.@asterisk.dumpcore",
  	maxcalls = "uci.pbx.asterisk.@asterisk.maxcalls",
 	nocolor = "uci.pbx.asterisk.@asterisk.nocolor",
  	live_dangerously  = "uci.pbx.asterisk.@asterisk.live_dangerously",
 	transcode_via_sln = "uci.pbx.asterisk.@asterisk.transcode_via_sln",
  	transmit_silence_during_record = "uci.pbx.asterisk.@asterisk.transmit_silence_during_record"
}

local content, helpmsg = post_helper.handleQuery(mapParams, mapValid)
-----------------------------------------------------------------------------------------
local debug1 = {
	{'0', '0'},
	{'1', '1'},
	{'2', '2'},
	{'3', '3'}
}

local verbose = {
	{'0', '0'},
	{'1', '1'},
	{'2', '2'},
	{'3', '3'}
}

local maxcalls = {
	{'5', '5'},
	{'0', '0'},
	{'1', '1'},
	{'2', '2'},
	{'3', '3'},
	{'4', '4'},
	{'5', '5'},
	{'6', '6'},
	{'7', '7'},
	{'8', '8'}
}
-----------------------------------------------------------------------------------------
local choice2 = {
	{"0",T"Disabled"},
	{"1",T"Enabled"}
}
------VoIP Trunks------------------------------------------------------------------------
local VoIP_columns = {
  {
    header = T"Provider Name",
    name = "name",
    param = "name",
    type = "text",
    default = "TIM",
    attr = { input = { class="span2" } },
  },
  {
    header = T"Num Tel",
    name = "defaultuser",
    param = "defaultuser",
    type = "text",
    default = "+3902123",    
    attr = { input = { class="span2" } },
  },
  {
    header = T"Password",
    name = "secret",
    param = "secret",
    type = "text",
    attr = { input = { class="span2" } },
--  gVP = true        To Do Fix
-- We skip reading off the saved value and return nothing, check empty and
-- we check the entered value against the saved one, and only write if the entered value is
-- something other than the empty string, and it differes from the saved value.
  },
  {
    header = T"SIP Server/Registrar/domain name",
    name = "host",
    param = "host",
    type = "text",
    default = "telecomitalia.it",
    attr = { input = { class="span2" } },
--  host.datatype = "host"
  },
  {
    header = T"Enable Incoming Calls (Register via SIP)",
    name = "register",
    param = "register",
    type = "switch",
    default = "1",
    attr = { switch = { ["data-placement"] = "right" }}
  },
  {
    header = T"Enable Outgoing Calls",
    name = "make_outgoing_calls",
    type = "switch",
    default = "1",
    attr = { switch = { ["data-placement"] = "right" }}
  },
  {
    header = T"Outbound Proxy",
    name = "outboundproxy",
    param = "outboundproxy",
    type = "text",
    default = "xxxx.xxxx.xxxx.telecomitalia.it",
    attr = { input = { class="span2" } },
--  op.datatype = "host" outboundproxy
  },
  {
    header = T"SIP Realm (needed by some providers)",
    name = "fromdomain",
    param = "fromdomain",
    type = "text",
    default = "telecomitalia.it",
    attr = { input = { class="span2" } },
--  from.datatype = "host"
  },
  {
    header = T"SIP Server/Registrar Port",
    name = "port",
    param = "port",
    type = "text",
    default = "5060",
    attr = { input = { class="span2" } },
  },
}

local VoIP_valid = {
--  To Do Fix  make sure the fields are not empty otherwise it will be a bug
    LastName = vNES,
}
-----------------------------------------------------------------------------------------
local VoIP_options = {
  tableid = "voip_provider",
  basepath    = "uci.pbx.",
  createMsg   = T"Add New VoIP Trunks",
  canAdd      = true,
  canDelete   = true,
  canApply    = true,
  canEdit     = true
}

local VoIP_data, VoIP_helpmsg = post_helper.handleTableQuery(VoIP_columns, VoIP_options, nil, nil, VoIP_valid)
-----------------------------------------------------------------------------------------
local canreinvite = {
	{"yes",T"Yes"},
	{"nonat",T"Yes when not behind NAT"},
	{"update",T"Use UPDATE rather than INVITE for path redirection"},
	{"no",T"No"},
}

local tech = {
	{"0",T"SIP"},
	{"1",T"IAX"}
}
------User Accounts----------------------------------------------------------------------
local SIP_columns = {
  {
    header = T"Technology",
    name = "technology",
    param = "technology",
        type = "select",
		values = tech,
    attr = { input = { class="span2" } },
  },
  {
    header = T"Full Name/Extension",
    name = "fullname",
    param = "fullname",
    type = "text",
    attr = { input = { class="span2" } },
  },
  {
    header = T"Password",
    name = "secretuser",
    param = "secretuser",
    type = "text",
    attr = { input = { class="span2" } },
--  Same as above password
  },
  {
    header = T"Receives Incoming Calls",
    name = "ring",
    param = "ring",
    type = "switch",
    default = "1",
    attr = { switch = { ["data-placement"] = "right" }}
  },
  {
    header = T"Makes Outgoing Calls",
    name = "can_call",
    param = "can_call",
    type = "switch",
    default = "1",
    attr = { switch = { ["data-placement"] = "right" }}
  },
  {
    header = T"Reinvite/redirect media connections",
    name = "canreinvite",
    param = "canreinvite",
        type = "select",
		values = canreinvite,
    attr = { input = { class="span2" } },
  },
  {
    header = T"Static",
    name = "FirstName",
    param = "FirstName",
    type = "switch",
    default = "1",
    attr = { switch = { ["data-placement"] = "right" }}
  },
  {
    header = T"Write Protect",
    name = "LastName",
    param = "LastName",
    type = "switch",
    default = "1",
    attr = { switch = { ["data-placement"] = "right" }}
  }
}

local SIP_valid = {
--  so we have to make sure the fields are not empty otherwise it will be a bug
    LastName = vNES,
}

local SIP_options = {
  tableid = "local_user",
  basepath    = "uci.pbx.",
  createMsg   = T"Add New User",
  canAdd      = true,
  canDelete   = true,
  canApply    = true,
  canEdit     = true
}

local SIP_data, SIP_helpmsg = post_helper.handleTableQuery(SIP_columns, SIP_options, nil, nil, SIP_valid)
------Some usefull function--------------------------------------------------------------
local function validate_phonenumber(value)
  if value == "" or value:match("^([%+%d]?[%d%s%-%#%*]+)$") then
    return true
  end
  return nil, "Invalid phone number"
end

local tolower = string.lower

local function sort_func(a, b)
  return tolower(a["FirstName"]) < tolower(b["FirstName"])
end

local uri = ngx.var.uri

if ngx.var.args and string.len(ngx.var.args) > 0 then
  uri = uri .. "?" .. ngx.var.args
end
-- Check availability of file, return true if found, else false
local function file_check(file_name)
  local file_found=io.open(file_name, "r")
  if file_found==nil then
    return false
  else
    return true
  end
end
------To Do Fix--------------------------------------------------------------------------
-- Recreate the config, and restart services after changes are commited to the configuration.
--[[if ngx.var.request_method == "POST" then
    -- local content = ngx.req.get_post_args()
    -- os.execute("/etc/init.d/pbx-asterisk restart 1\>/dev/null 2\>/dev/null")
    -- os.execute("/etc/init.d/asterisk restart 1\>/dev/null 2\>/dev/null")
end]]--
-- createInputText with this info
-- regs = luci.sys.exec("asterisk -rx 'sip show registry' | sed 's/peer-//'")
-- jabs = luci.sys.exec("asterisk -rx 'jabber show connections' | grep onnected")
-- usrs = luci.sys.exec("asterisk -rx 'sip show users'")
-- chan = luci.sys.exec("asterisk -rx 'core show channels'")
-----------------------------------------------------------------------------------------
%>
<%= ui_helper.createHeader(T"Telephony", false, true) %>

<div class="modal-body update">
  <%
  local lp = require("web.lp")
  lp.setpath("/www/snippets/")
  lp.include("tabs-voice.lp")
  %>
  <form class="form-horizontal" method="post" action="<%= uri %>">
    <fieldset>
      <legend><%= T"Asterisk General Options" %></legend>
      <%=ui_helper.createAlertBlock(T"This configuration page allows you to configure a phone system (PBX) service.", info_box)%>
      <%=ui_helper.createSwitch(T"Cache recorded sound files during recording", "cache_record_files", content["cache_record_files"])%>
      <%=ui_helper.createInputSelect(T"Debug Level", "debug1", debug1 , content["debug1"])%>
      <%=ui_helper.createInputSelect(T"Verboses Level", "verbose", verbose , content["verbose"])%>
      <%=ui_helper.createSwitch(T"Disable some warnings", "dontwarn", content["dontwarn"])%>
      <%=ui_helper.createSwitch(T"Dump core on crash", "dumpcore", content["dumpcore"])%>
      <%=ui_helper.createInputSelect(T"Maximum number of calls allowed", "maxcalls", maxcalls , content["maxcalls"])%>		
      <%=ui_helper.createSwitch(T"Disable console colors", "nocolor", content["nocolor"])%>
      <%=ui_helper.createSwitch(T"Enable the execution of dangerous dialplan", "live_dangerously", content["live_dangerously"])%>
      <%=ui_helper.createSwitch(T"Build transcode paths via SLINEAR, not directly", "transcode_via_sln", content["transcode_via_sln"])%>
      <%=ui_helper.createSwitch(T"Transmit SLINEAR silence while recording a channel", "transmit_silence_during_record", content["transmit_silence_during_record"])%>
    </fieldset>
    <fieldset>
      <legend><%= T"SIP VoIP Provider Accounts Trunks" %></legend>
      <%=ui_helper.createAlertBlock(T"This is where you set up VoIP accounts for any providers in order to start using them for dialing and receiving calls.", info_box)%>
      <%=ui_helper.createTable(VoIP_columns, VoIP_data, VoIP_options, nil, VoIP_helpmsg)%>
    </fieldset>
    <fieldset>
      <legend><%= T"SIP/IAX User Accounts" %></legend>
      <%=ui_helper.createAlertBlock(T"Here you must configure at least one SIP account, that you will use to register with this service. Use in an Analog Telephony Adapter (ATA), or in a SIP software.", info_box)%>
      <%=ui_helper.createTable(SIP_columns, SIP_data, SIP_options, nil, SIP_helpmsg)%>
    </fieldset>
  </form>
</div><%= ui_helper.createFooter() %>
