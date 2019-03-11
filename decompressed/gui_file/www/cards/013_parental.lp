<%
-- NG-82219
-- Enable localization
gettext.textdomain('webui-parental')

local format = string.format
local table = table
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
-- local tprint = require("tch.tableprint")
local uniqueKey = post_helper.getRandomKey()

local content_parental = {
  state = "uci.parental.general.enable",
  exclude = "uci.parental.general.exclude",
}
content_helper.getExactContent(content_parental)

local uci_parental_path = "uci.parental.URLfilter.@."
local parental_columns = {
    {
        header = T"Site",
        name = "site",
        param = "site",
        type = "text",
        attr = { input = { class="span2" } },
    },
    {
        header = T"Device",
        name = "device",
        param = "device",
        type = "text",
        attr = { input = { class="span2"} },
    },
}

local parental_options = {
    tableid         = "urlfilter",
    basepath        = uci_parental_path,
	objectName      = uniqueKey,
    addNamedObject  = true,				   
}

-- get an initial read from UCI
local parental_data = post_helper.handleTableQuery(parental_columns, parental_options)
local rulecount = 0

-- Parental Control data
function updataParentalTableData ()
    local data = parental_data
    local urlCount = 0
    local id = 0

    -- just looking for a count of entries to return for now
    for id, val in ipairs (data) do
	    urlCount = id
    end
    return data, urlCount
end

parental_data, rulecount = updataParentalTableData()

local blockenabled = true
local switchtext
local n_block_rules

if (content_parental["state"] == '1') then
    switchtext = T"Site blocking enabled"
    blockenabled = "1"
else
    switchtext = T"Site blocking disabled"
    blockenabled = "0"
end

n_block_rules = tonumber(rulecount)

local modalPath = nil
local switchName = nil
local modal_link = ""				 
local session = ngx.ctx.session
if session:hasAccess("/modals/parental-modal.lp") then
    modalPath = "/modals/parental-modal.lp"
	modal_link = 'class="modal-link" id = "Site_Blocking_Count" data-toggle="modal" data-remote="/modals/parental-modal.lp" data-id="parental-modal"'																																				
end
%>
 
<div class="span3">
  <div class="smallcard" data-aos="zoom-in" data-aos-anchor-placement="center-bottom" data-aos-easing="ease-in-back">

    <%= ui_helper.createCardHeader(T"Parental Controls", modalPath, switchName, nil) %>

    <div class="content card_bg" data-bg-text="&#xf023;">
	<div class="divtable">
    <% ngx.print(
            ui_helper.createSimpleLight(blockenabled, switchtext, { light = { id =  "Site_BlockingStatus_Led" }, span = { id =  "Site_Blocking_Status" } },"fa-ban"),
            '<p></p>',
            '<p class="subinfos">',
            format( N("<strong %s>%d site blocking</strong> rule is defined",
                      "<strong %s>%d site blocking</strong> rules are defined", n_block_rules),
                      modal_link, n_block_rules),
            '</p>'
            )

    %>
    </div>
	</div>
  </div>
</div>
