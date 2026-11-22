--pretranslated: do not change this file

-- Enable localization
-- NG-49075 Version 001 160429
-- NG-73564;

gettext.textdomain('webui-voice')

local proxy = require ("datamodel")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local content_helper = require ("web.content_helper")
local uimessage_helper = require("web.uimessage_helper")
local role = ngx.ctx.session:getrole()
local vNES = post_helper.validateNonEmptyString

local function voicePath(port, suffix, read, ...)
    local relative = ".Services.VoiceService.1.PhyInterface." .. port .. suffix
    for _, root in ipairs({"Device", "InternetGatewayDevice"}) do
        local path = root .. relative
        local result = read(path, ...)
        if result and result[1] then
            return path
        end
    end
end

local mapParam, mapValid = {}, {}
for port = 1, 2 do
    local path = voicePath(port, ".X_000E50_POSConfig", proxy.get)
    if path then
        local field = "posfxs" .. port
        mapParam[field] = path
        mapValid[field] = vNES
    end
end

local content = {}
if next(mapParam) then
    content = post_helper.handleQuery(mapParam, mapValid)
end

local choice2 = {
					{"0",T"Disabled"},
					{"1",T"Enabled"},

				}

local codec_columns = {
    { --[1]
        header = T"Name",
        name = "profile",
        param = "Codec",
        type = "text",
		readonly = true,
        attr = { input = { class="span2" } },
    },
    { --[2]
		header = T"State",
        name = "enable",
        param = "Enable",
        type = "select",
		values = choice2,
        attr = { select = { class="span2" } },
    },
    { --[3]
        header = T"Priority",
        name = "priority",
        param = "Priority",
        type = "text",
        attr = { input = { class="span2" } },
    },
	{ --[4]
        header = T"Packetization Period",
        name = "PacketizationPeriod",
        param = "PacketizationPeriod",
        type = "text",
		readonly = true,
        attr = { input = { class="span2" } },
    },
	{ --[5]
        header = T"Bit Rate",
        name = "BitRate",
        param = "BitRate",
        type = "text",
        readonly = true,
        attr = { input = { class="span2" } },
    },
    { --[6]
        header = T"Silence Suppression",
        name = "supression",
        param = "SilenceSuppression",
        type = "select",
		values = choice2,
        attr = { select = { class="span2" } },
    },
}

--maybe getValidateNumberInRange instead of validatePositiveNum (vPN)
local gVIESc2 = post_helper.getValidateInEnumSelect(choice2)
local vPN = post_helper.validatePositiveNum
local codec_valid = {
						profile = vNES,
						enable = gVIESc2,
						priority = vPN,
						PacketizationPeriod = vPN,
						BitRate = vPN,
						supression = gVIESc2,
						}
						
local codec_options, codec_data, codec_helpmsg = {}, {}, {}
for port = 1, 2 do
    local path = voicePath(port, ".X_000E50_Codec.List.", proxy.getPN, true)
    if path then
        local options = {
            canEdit = true,
            canAdd = false,
            canDelete = false,
            tableid = "codecFXS" .. port,
            basepath = path,
        }
        codec_options[port] = options
        codec_data[port], codec_helpmsg[port] = post_helper.handleTableQuery(codec_columns, options, nil, nil, codec_valid)
    end
end

local uri = ngx.var.uri
if ngx.var.args and string.len(ngx.var.args) > 0 then
    uri = uri .. "?" .. ngx.var.args
end


ngx.print( ui_helper.createHeader(T"Telephony", false, true) )
ngx.print('\
<div class="modal-body update">\
  ')
  local lp = require("web.lp")
  lp.setpath("/www/snippets/")
  lp.include("tabs-voice.lp")
  
ngx.print('\
  <form class="form-horizontal" method="post" action="'); ngx.print( uri ); ngx.print('">\
    '); ngx.print ( ui_helper.createMessages(uimessage_helper.popMessages()) ); ngx.print('\
    <fieldset>\
      <legend>'); ngx.print( T"Enable Pos" ); ngx.print('</legend>\
		')
			local Posswitch = {
									values = {on = "true", off = "false"},
									}
			local html = {}
			if mapParam.posfxs1 then
				html[#html+1] = ui_helper.createSwitch(T"Pos on FXS1", "posfxs1", content.posfxs1, Posswitch)
			end
			if mapParam.posfxs2 then
				html[#html+1] = ui_helper.createSwitch(T"Pos on FXS2", "posfxs2", content.posfxs2, Posswitch)
			end
			
			ngx.print(html)
		
		ngx.print('\
    </fieldset>\
	')
  if role == "engineer" then
  
	html = {}
	
    local headings = {T"Codec Assignment on FXS1", T"Codec Assignment on FXS2"}
    for port = 1, 2 do
        if codec_options[port] then
            html[#html+1] = '<fieldset>'
            html[#html+1] = '<legend>' .. headings[port] .. '</legend>'
            html[#html+1] = ui_helper.createTable(codec_columns, codec_data[port], codec_options[port], nil, codec_helpmsg[port])
            html[#html+1] = '</fieldset>'
        end
    end
	
	ngx.print(html)
  end
  ngx.print('\
  </form>\
 </div>\
\
'); ngx.print( ui_helper.createFooter() );
