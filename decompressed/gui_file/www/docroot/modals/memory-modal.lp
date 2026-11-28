--pretranslated: do not change this file

-- Localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")

local rows = {}
local f = io.open("/proc/meminfo", "r")
if f then
	for line in f:lines() do
		local key, value = line:match("^([%w_%(%)]+):%s+(%d+)")
		if key then
			rows[#rows + 1] = { key = key, kb = tonumber(value) }
		end
	end
	f:close()
end

local format = string.format

local function escape_html(value)
	return (value or ""):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"):gsub("'", "&#39;")
end

-- Read the filesystem used by the installers, not the inactive firmware bank.
local has_posix, posix = pcall(require, "tch.posix")
local function free_space(path)
	if has_posix then
		local ok, stat = pcall(posix.statvfs, path)
		if ok and type(stat) == "table" then
			local blocks = tonumber(stat.f_bavail)
			local size = tonumber(stat.f_frsize) or tonumber(stat.f_bsize)
			if blocks and size and blocks >= 0 and size > 0 then
				local mib = blocks * size / 1048576
				return mib >= 1024 and format("%.2f GiB", mib / 1024) or format("%.2f MiB", mib)
			end
		end
	end
	return T"Unavailable"
end

local storage_rows = {
	{ name = T"Internal storage", free = free_space("/usr") },
}
local mounts = io.open("/proc/mounts", "r")
local usb_found = false
if mounts then
	for line in mounts:lines() do
		local device, mount, options = line:match("^(%S+)%s+(%S+)%s+%S+%s+(%S+)")
		if device and device:match("^/dev/sd[a-z]%d*$") and mount:match("^/tmp/run/mountd/sd[a-z]%d*$") then
			usb_found = true
			local readonly = not ("," .. options .. ","):find(",rw,", 1, true)
			storage_rows[#storage_rows + 1] = {
				name = "USB " .. escape_html(device:match("[^/]+$")),
				free = free_space(mount) .. (readonly and (" (" .. T"Read-only" .. ")") or ""),
			}
		end
	end
	mounts:close()
end
if not usb_found then
	storage_rows[#storage_rows + 1] = { name = T"USB: no mounted drive", free = "-" }
end

ngx.print('\
');  ngx.print( ui_helper.createHeader(T"Memory", false, false) ); ngx.print('\
<div class="modal-body update">\
  <form class="form-horizontal" method="post" action="modals/memory-modal.lp">\
  </form>\
  <fieldset>\
    <legend>');  ngx.print( T"Memory details" ); ngx.print('</legend>\
    ');

local html = {}
if #rows == 0 then
	html[#html + 1] = '<div class="alert alert-error">' .. T"/proc/meminfo is not readable" .. '</div>'
else
	html[#html + 1] = '<table class="table table-striped table-bordered"><thead><tr><th>' .. T"Item" .. '</th><th>kB</th><th>MB</th></tr></thead><tbody>'
	for i = 1, #rows do
		html[#html + 1] = string.format('<tr><td>%s</td><td>%d</td><td>%.1f</td></tr>', rows[i].key, rows[i].kb, rows[i].kb / 1024)
	end
	html[#html + 1] = '</tbody></table>'
end
ngx.print(html)

ngx.print('\
  </fieldset>\
  <fieldset>\
    <legend>');  ngx.print( T"Available space" ); ngx.print('</legend>\
    ');

local storage_html = {}
storage_html[#storage_html + 1] = '<table class="table table-striped table-bordered"><thead><tr><th>' .. T"Item" .. '</th><th>' .. T"Available space" .. '</th></tr></thead><tbody>'
for i = 1, #storage_rows do
	storage_html[#storage_html + 1] = format('<tr><td>%s</td><td>%s</td></tr>', storage_rows[i].name, storage_rows[i].free)
end
storage_html[#storage_html + 1] = '</tbody></table>'
ngx.print(storage_html)

ngx.print('\
  </fieldset>\
</div>\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
');
