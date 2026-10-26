--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local message_helper = require("web.uimessage_helper")
local format = string.format
local tonumber = tonumber

local ds_channels_columns = {
  {--[1]
    header = T"Channel",
    name = "channel_idx",
    param = "channel_idx",
    type = "text",
    readonly = true,
  },
  {--[2]
    header = T"Lock Status",
    name = "lock_status",
    param = "lock_status",
    type = "text",
    readonly = true,
  },
  {--[3]
    header = T"Modulation",
    name = "modulation",
    param = "modulation",
    type = "text",
    readonly = true,
  },
  {--[4]
    header = T"Channel ID",
    name = "channel_id",
    param = "channel_id",
    type = "text",
    readonly = true,
  },
  {--[5]
    header = T"Frequency",
    name = "frequency",
    param = "frequency",
    type = "text",
    readonly = true,
  },
  {--[6]
    header = T"Power",
    name = "power",
    param = "power",
    type = "text",
    readonly = true,
  },
  {--[7]
    header = T"MSE",
    name = "mse",
    param = "mse",
    type = "text",
    readonly = true,
  },
  {--[8]
    header = T"Correctables",
    name = "correctables",
    param = "correctables",
    type = "text",
    readonly = true,
  },
  {--[9]
    header = T"Uncorrectables",
    name = "uncorrectables",
    param = "uncorrectables",
    type = "text",
    readonly = true,
  },
}

local function sort_func(a, b)
  return tonumber(a["channel_idx"]) < tonumber(b["channel_idx"])
end

local ds_channels_options = {
    canEdit = false,
    canAdd = false,
    canDelete = false,
    tableid = "ds_channels",
    basepath = "rpc.docsis.ds_channels.",
    sorted = sort_func,
}

local locked_ds_channels_options = {
    canEdit = false,
    canAdd = false,
    canDelete = false,
    tableid = "locked_ds_channels",
    basepath = "rpc.docsis.ds_channels.",
    sorted = sort_func,
}

local us_channels_columns = {
  {--[1]
    header = T"Channel",
    name = "channel_idx",
    param = "channel_idx",
    type = "text",
    readonly = true,
  },
  {--[2]
    header = T"Enabled",
    name = "enabled",
    param = "enabled",
    type = "text",
    readonly = true,
  },
  {--[3]
    header = T"Modulation",
    name = "modulation",
    param = "modulation",
    type = "text",
    readonly = true,
  },
  {--[4]
    header = T"Channel ID",
    name = "channel_id",
    param = "channel_id",
    type = "text",
    readonly = true,
  },
  {--[5]
    header = T"Frequency",
    name = "frequency",
    param = "frequency",
    type = "text",
    readonly = true,
  },
  {--[6]
    header = T"Power",
    name = "power",
    param = "power",
    type = "text",
    readonly = true,
  },
  {--[7]
    header = T"Symbol Rate",
    name = "sym_rate",
    param = "sym_rate",
    type = "text",
    readonly = true,
  },
}

local us_channels_options = {
    canEdit = false,
    canAdd = false,
    canDelete = false,
    tableid = "us_channels",
    basepath = "rpc.docsis.us_channels.",
    sorted = sort_func,
}

local locked_us_channels_options = {
    canEdit = false,
    canAdd = false,
    canDelete = false,
    tableid = "locked_us_channels",
    basepath = "rpc.docsis.us_channels.",
    sorted = sort_func,
}

local ds_filter_func = function(data)
  return data["lock_status"] == "Locked"
end

local us_filter_func = function(data)
  return data["enabled"] == "Enabled"
end

local locked_ds_channels_data, locked_ds_channels_helpmsg = post_helper.handleTableQuery(ds_channels_columns, locked_ds_channels_options, ds_filter_func)
local ds_channels_data, ds_channels_helpmsg = post_helper.handleTableQuery(ds_channels_columns, ds_channels_options)
local locked_us_channels_data, locked_us_channels_helpmsg = post_helper.handleTableQuery(us_channels_columns, locked_us_channels_options, us_filter_func)
local us_channels_data, us_channels_helpmsg = post_helper.handleTableQuery(us_channels_columns, us_channels_options)

local status = {
  docsis_status = "rpc.docsis.status",
}

-- Get the content
content_helper.getExactContent(status)

  ngx.print('\
\
<div class="modal-body update" style="overflow:visible">\
  <form class="form-horizontal" method="post" action="modals/broadband-docsis.lp">\
  ');  
    ngx.print(ui_helper.createMessages(message_helper.popMessages()))
    ngx.print('\
    <fieldset>\
    <legend>');  ngx.print( T"Status" ); ngx.print('</legend>\
\
     ');  
        local html = {}

        -- Attributes (in order to display a different table in basic/advanced mode)
		local attributesBasic = { group = { class = "advanced" },
  		   span = { class = "span4" } }
        local attributesAdvanced = { group = { class = "advanced hide" },
          span = { class = "span4" } }

        -- Icons
        local statusIcon
        if (status["docsis_status"] == "Operational") then
          statusIcon = "<div class=\"light green\"></div>"
        elseif status["docsis_status"] == "Not Synchronized" then
          statusIcon = "<div class=\"light red\"></div>"
        else
          statusIcon = "<div class=\"light orange\"></div>"
        end

        html[#html + 1] = ui_helper.createLabel(
            T"DOCSIS Status", format("%s%s", statusIcon,
            T(status["docsis_status"])))

        local docsis_ipaddr = {
            docsis_mgt_ipaddr = "rpc.docsis.interface.ipaddr",
            internet_ipaddr = "rpc.network.interface.@wan.ipaddr",
        }

        content_helper.getExactContent(docsis_ipaddr)

        html[#html+1] = ui_helper.createLabel(T"DOCSIS IP address", docsis_ipaddr["docsis_mgt_ipaddr"])
        html[#html+1] = ui_helper.createLabel(T"Internet IP address", docsis_ipaddr["internet_ipaddr"])

        ngx.print(html)
	   ngx.print('\
        <legend>');  ngx.print( T"Downstream Bonded Channels" ); ngx.print('</legend>\
     ');  
	    ngx.print(ui_helper.createTable(ds_channels_columns, locked_ds_channels_data, locked_ds_channels_options, attributesBasic, locked_ds_channels_helpmsg))
	    ngx.print(ui_helper.createTable(ds_channels_columns, ds_channels_data, ds_channels_options, attributesAdvanced, ds_channels_helpmsg))
       ngx.print('\
        <legend>');  ngx.print( T"Upstream Bonded Channels" ); ngx.print('</legend>\
     ');  
	    ngx.print(ui_helper.createTable(us_channels_columns, locked_us_channels_data, locked_us_channels_options, attributesBasic, locked_us_channels_helpmsg))
	    ngx.print(ui_helper.createTable(us_channels_columns, us_channels_data, us_channels_options, attributesAdvanced, us_channels_helpmsg))
       ngx.print('\
    </fieldset>\
  </form>\
</div>\
'); 