--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-printersharing')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local attributes = { span = { class = "span4" } }
local message_helper = require("web.uimessage_helper")
local format = string.format

local mapParams = {
  printersharing_enabled = "uci.printersharing.config.enabled",
}

local mapValid = {
  printersharing_enabled = post_helper.validateBoolean,
}

local content, helpmsg = post_helper.handleQuery(mapParams, mapValid)

local content_samba = {
  samba_enabled   = "uci.samba.samba.enabled",
  hostname        = "uci.system.system.@system[0].hostname",
  localdevIP      = "uci.network.interface.@lan.ipaddr",
}

content_helper.getExactContent(content_samba)
-- usb Devices
local usbdev_columms = {
  {
     header = T"Port",
     type = "text",
     readonly = true,
  },
  {
     header = T"Product Name",
     type = "text",
     readonly = true,
  },
  {
     header = T"Manufacturer",
     type = "text",
     readonly = true,
  },
  {
     header = T"Version",
     type = "text",
     readonly = true,
  },
}

local usbdev_options = {
    tableid = "usbDev",
    basepath = "sys.usb.device.",
    canAdd = false,
    canEdit = false,
    canDelete = false,
}

local usbpart_data = {}
local function createUsbPartitionTable()
    local usbdev_data = proxy.get("sys.usb.")
    if not usbdev_data then
        return
    end

    local path_list = {}
    for _, v in ipairs(usbdev_data) do
      if v.param == "bInterfaceClass" and v.value == "07" then
         path_list[#path_list+1] = string.match(v.path, "(sys.usb.device.%d+.)interface.%d+.$")
      end
    end

    for i=1, #path_list do
      usbpart_data[i]={}
      for j=1,#usbdev_columms,1 do
        usbpart_data[i][j] = " "
      end
      local params_t =
      {
        [ "path" .. path_list[i] ]  = 1,
        [ "product" .. path_list[i] ] = 2,
        [ "manufacturer" .. path_list[i] ] = 3,
        [ "version" .. path_list[i] ] = 4,
      }
      for _, v in ipairs(usbdev_data) do
        if v.param and v.path and params_t[v.param .. v.path] then
          usbpart_data[i][params_t[v.param .. v.path]] = v.value
        end
      end --endof for usbdev_data
    end   --endof for #path_list
end

createUsbPartitionTable()

local function concatPrinter(printer_table, delimiter)
    local result = ""
    for _, v in ipairs(printer_table) do
      result = result .. delimiter .. v
    end
    return result
end

local function removeDuplicateEntry(usbpart_data)
    local tableDict, duplicateIndices = {}, {}
    -- Converts all nested tables into string and also to find all duplicate indices
    for i, t in ipairs(usbpart_data) do
      local key = concatPrinter(t, "|")
      if not tableDict[key] then
        tableDict[key] = true
      else
         duplicateIndices[#duplicateIndices+1] = i
      end
    end
    -- Iteration over duplicate indices from backwards and removed the value
    for i = #duplicateIndices, 1, -1 do
      table.remove(usbpart_data, duplicateIndices[i])
    end
    return usbpart_data
end

removeDuplicateEntry(usbpart_data)

  ngx.print('\
\
');  ngx.print( ui_helper.createHeader(T"Printer Sharing", false, true, nil)); ngx.print('\
<div class="modal-body update">\
  <form class="form-horizontal" method="post" action="modals/printersharing-modal.lp">\
    ');  ngx.print(ui_helper.createMessages(message_helper.popMessages())); ngx.print('\
    ');  
      html = {}
      html[#html+1] = ui_helper.createSwitch(T"Enabled", "printersharing_enabled", content["printersharing_enabled"], attributes)
      html[#html+1] = "<fieldset><legend>" .. T"Printer Information" .. "</legend>"
      if content.printersharing_enabled == '1' then
        if content_samba.samba_enabled == '1' then
          html[#html+1] = format(T'<div class=\" simple-desc span4\">To connect: \\\\%s\\ or \\\\%s\\</div>',content_samba.localdevIP,content_samba.hostname)
        else
          html[#html+1] = format(T'<div class=\" simple-desc span4\">Samba is disabled</div>')
        end
      end
      html[#html+1] = ui_helper.createTable(usbdev_columms, usbpart_data, usbdev_options, nil, usbdev_helpmsg)
      html[#html+1] = "</fieldset>"
      ngx.print(html)
      ngx.print('\
  </form>\
</div>\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
'); 