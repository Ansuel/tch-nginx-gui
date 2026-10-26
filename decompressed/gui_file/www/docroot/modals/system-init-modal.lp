--pretranslated: do not change this file

-- Localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")

local function valid_init(name)
	if type(name) ~= "string" or not name:match("^[%w_.%-]+$") then
		return false
	end
	local file = io.open("/etc/init.d/" .. name, "r")
	if not file then return false end
	file:close()
	return true
end

if ngx.req.get_method() == "POST" then
	local action = ngx.req.get_post_args().action
	local cmd, name
	if action then
		action = string.untaint(action)
		cmd, name = action:match("^([a-z]+)_([%w_.%-]+)$")
	end
	ngx.header.content_type = "application/json"
	if valid_init(name) then
		if cmd == "status" then
			local function state(parameter)
				local result = proxy.get("rpc.system.init.files.@" .. name .. "." .. parameter)
				return result and result[1] and result[1].value == "1"
			end
			ngx.print('{"success":true,"running":' .. tostring(state("running")) .. ',"enabled":' .. tostring(state("active")) .. '}')
			return ngx.exit(ngx.HTTP_OK)
		elseif cmd == "start" or cmd == "stop" or cmd == "restart" or cmd == "enable" or cmd == "disable" then
			local ok, err = proxy.set("rpc.system.init." .. cmd, name)
			if ok then ok, err = proxy.apply() end
			if ok then
				ngx.print('{"success":true}')
				return ngx.exit(ngx.HTTP_OK)
			end
			ngx.log(ngx.ERR, "init action failed: ", err or "unknown error")
			ngx.print('{"success":false}')
			return ngx.exit(ngx.HTTP_OK)
		end
	end
	ngx.print('{"success":false}')
	return ngx.exit(ngx.HTTP_OK)
end

local init_columns = {
	{ --[1]
		header = T"Enabled at boot",
		name = "active",
		param = "active",
		type = "light",
	},
	{ --[2]
		header = T"Name",
		name = "name",
		param = "name",
		type = "text",
	},
	{ --[3]
		header = T"Start Order",
		name = "start_order",
		param = "start_order",
		type = "text",
	},
	{ --[4]
		header = T"Stop Order",
		name = "stop_order",
		param = "stop_order",
		type = "text",
	},
	{ --[5]
		header = T"Toggle",
		name = "toggle",
		param = "toggle",
		type = "text",
	},
	{ --[6]
		header = T"Start",
		name = "start",
		param = "start",
		type = "text",
	},
	{ --[7]
		header = T"Stop",
		name = "stop",
		param = "stop",
		type = "text",
	},
	{ --[8]
		header = T"Restart",
		name = "restart",
		param = "restart",
		type = "text",
	}
}

local init_options = {
	canEdit = false,
	canAdd = false,
	canDelete = false,
	tableid = "inittable",
	basepath = "rpc.system.init.files.",
	sorted = "start_order",
}

local init_filter = function(data)

	if data.start_order == "" then
		return false
	end

	local function genAttrib(type)
		return {
			button = {
			  class = "btn-"..type,
			  ["data-name"] = data.name
			}
		}
	end

	if data.active == "1" then
		data.toggle = ui_helper.createSimpleButton(T"Disable","refresh",genAttrib("disable"))
	else
		data.toggle = ui_helper.createSimpleButton(T"Enable","refresh",genAttrib("enable"))
	end
	data.restart = ui_helper.createSimpleButton(T"Restart","refresh",genAttrib("restart"))
	data.start = ui_helper.createSimpleButton(T"Start","refresh",genAttrib("start"))
	data.stop = ui_helper.createSimpleButton(T"Stop","refresh",genAttrib("stop"))

	return true
end

local init_data, sipnet_helpmsg = post_helper.handleTableQuery(init_columns, init_options, init_filter)

  ngx.print('\
');  ngx.print(ui_helper.createHeader(T"Management", false, false) ); ngx.print('\
<div class="modal-body update">\
');
  local lp = require("web.lp")
  lp.setpath("/www/snippets/")
  lp.include("tabs-management.lp")
  ngx.print('\
');
-- dummy form so that refresh button knows which page to reload, keep it
  ngx.print('\
  <form class="form-horizontal" method="post" action="modals/system-init-modal.lp">\
  </form>\
  <fieldset id="system-init-tab">\
	<fieldset>\
	<legend>');  ngx.print( T"Init Management" ); ngx.print('</legend>')

	local alert_warn = {
		alert = {
			class = "alert alert-warn"
		},
	}

	ngx.print(ui_helper.createAlertBlock(T"Don't randomly disable or restart Init Process. Some Init are crucial for the correct boot of the device.",alert_warn))
	ngx.print(ui_helper.createTable(init_columns, init_data, init_options))

	ngx.print('\
	</fieldset>\
  </fiedlset>\
  </div>\
  <script>\
	$("#inittable .btn-start, #inittable .btn-stop, #inittable .btn-restart, #inittable .btn-enable, #inittable .btn-disable").on("click", function(){\
		var button = $(this);\
		var row = button.closest("tr");\
		var name = button.data("name");\
		var action = button.attr("class").match(/btn-(start|stop|restart|enable|disable)/)[1];\
		var result = row.find(".init-action-status");\
		if (!result.length) {\
			result = $("<span>").addClass("init-action-status").attr("role", "status").appendTo(button.parent());\
		}\
		result.text("Sending " + action + "...");\
		$.post("modals/system-init-modal.lp", { action: action + "_" + name, CSRFtoken: $("meta[name=CSRFtoken]").attr("content") }, null, "json")\
			.done(function(response) {\
				if (!response.success) { result.text("Command failed"); return; }\
				result.text("Checking status...");\
				setTimeout(function() {\
					$.post("modals/system-init-modal.lp", { action: "status_" + name, CSRFtoken: $("meta[name=CSRFtoken]").attr("content") }, null, "json")\
						.done(function(status) {\
							var toggle = row.find(".btn-enable, .btn-disable");\
							toggle.removeClass("btn-enable btn-disable").addClass(status.enabled ? "btn-disable" : "btn-enable")\
								.text(status.enabled ? "Disable" : "Enable");\
							row.find("td:first .light").removeClass("green off").addClass(status.enabled ? "green" : "off");\
							result.text((status.running ? "Running" : "Stopped") + "; " + (status.enabled ? "enabled" : "disabled") + " at boot");\
						})\
						.fail(function() { result.text("Command sent; status unavailable"); });\
				}, 1500);\
			})\
			.fail(function() { result.text("Command failed"); });\
	});\
  </script>\
');  ngx.print(ui_helper.createFooter() ); ngx.print('\
');
