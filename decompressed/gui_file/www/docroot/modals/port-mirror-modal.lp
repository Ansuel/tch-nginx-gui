<%
-- Enable localization
gettext.textdomain('webui-core')

local lp = require("web.lp")
local tinsert = table.insert
local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local message_helper = require("web.uimessage_helper")
local ipairs = ipairs
local format, find, sub, untaint, match  = string.format, string.find, string.sub, string.untaint,string.match
local gVIES = post_helper.getValidateInEnumSelect

local dir_list = {
  {"any", T"any"},
  {"in", T"in"},
  {"out", T"out"},
}


local src_list={{"",T"NULL"}}
local atmintfs = proxy.getPN("uci.xtm.atmdevice.",true)
if (atmintfs ~= nil) then
  for _,v in ipairs (atmintfs) do
     local str =  v["path"]
     local atm  = match(str,"@([^@%.]-)%.")
     if atm ~= nil then
       src_list[#src_list +1] = {atm, atm}
     end
  end
end

local ptmintfs = proxy.getPN("uci.xtm.ptmdevice.",true)
if (ptmintfs ~= nil) then
  for _,v in ipairs (ptmintfs) do
     local str =  v["path"]
     local ptm = match(str,"@([^@%.]-)%.")
     if (ptm ~= nil ) then
       src_list[#src_list +1] = {ptm, ptm}
     end
  end
end


local get_list = {
  intfs = "uci.network.interface.@lan.device",
}
content_helper.getExactContent(get_list)

local dst_list={{"",T"NULL"}}
for i in string.gmatch(untaint(get_list.intfs), "%w+") do
  dst_list[#dst_list + 1] = {i, i}
end

local mapValid = {
      src_intf  = gVIES(src_list),
      dst_intf  = gVIES(dst_list),
      direction = gVIES(dir_list),
}


local function valid_args(add_args)
  if add_args == nil then
    return false
  end
  local content = {}
  for k,v in pairs(add_args) do
    content[k] = v
  end
  local validated ,helpmsg  = content_helper.validateObject(content, mapValid)
  if not validated then
    return false
  end

  local portmirror_base_path = "uci.portmirror.portmirror."
  local num = proxy.get("uci.portmirror.portmirrorNumberOfEntries")
  if num == 0 or num == nil then
     return true
  else
     local portmirror_inst= proxy.getPN(portmirror_base_path,true)
     if (portmirror_inst == nil) then
        return true
     else
        local srcintf_toadd = add_args["src_intf"]
        local dstintf_toadd =  add_args["dst_intf"]
        local direction_toadd =  add_args["direction"]
        for name,v in ipairs (portmirror_inst) do
           if find(v["path"],"gui") == nil  then
              local srcintf_trv = proxy.get(v["path"] .. "srcintf")
              local dstintf_trv =  proxy.get(v["path"] .. "dstintf")
              local direction_trv =  proxy.get(v["path"] .. "direction")
              if srcintf_toadd == srcintf_trv[1].value and  direction_toadd == direction_trv[1].value and dstintf_trv[1].value == dstintf_toadd then
                 return false
              end
          end
       end
    end
  end
  return true
end


local function EditGuiPortmirror(add_args)
  if (add_args == nil ) then
    message_helper.pushMessage(T"Error while applying changes", "error")
  else
    if(valid_args(add_args) == false) then
      message_helper.pushMessage(T"Error while applying changes", "error")
    else
      local portmirror_gui_path =  "uci.portmirror.portmirror.@gui."
      local portmirror_base_path = "uci.portmirror.portmirror."
      local state = proxy.get(portmirror_gui_path .. "srcintf")
      if ( add_args["src_intf"] ~= "" ) and (add_args["dst_intf"] ~= "" ) then
        if state == nil then
          proxy.add(portmirror_base_path,"gui")
        end
        proxy.set(portmirror_gui_path .. "srcintf", add_args["src_intf"])
        proxy.set(portmirror_gui_path .. "dstintf", add_args["dst_intf"])
        proxy.set(portmirror_gui_path .. "direction", add_args["direction"])
        local ok, msg = proxy.apply()
        ---bcm-lua should provide way of getting result of setportmirror for gui to push message according to that result
        ---now it always succeeds even setportmirror error
        if not ok then
          ngx.log(ngx.ERR, "apply failed: " .. msg)
          message_helper.pushMessage(T"Error while applying changes", "error")
        else
          message_helper.pushMessage(T"Changes saved successfully", "success")
        end
      else
        if state ~= nil then
          proxy.set(portmirror_gui_path .. "dstintf", "")
          local ok, msg = proxy.apply()
          if ok then
            ok, msg = proxy.del(portmirror_base_path .."@gui.")
            if not ok then
              message_helper.pushMessage(T"Error while applying changes", "error")
            else
              message_helper.pushMessage(T"Stop portmirror successfully", "success")
            end
          else
            message_helper.pushMessage(T"Error while applying changes", "error")
          end
        else
          message_helper.pushMessage(T"Invalid configuration", "error")
        end
      end
    end
  end
end


if ngx.req.get_method() == "POST" and (ngx.req.get_post_args().action == "SAVE") then
  local add_args = ngx.req.get_post_args()

-- do not call get_post_args before we know that we don't have a file sent otherwise it will fail
  EditGuiPortmirror(add_args)
end

local gui_pm_content = {
    src_intf	= "uci.portmirror.portmirror.@gui.srcintf",
    dst_intf	= "uci.portmirror.portmirror.@gui.dstintf",
    direction	= "uci.portmirror.portmirror.@gui.direction",
}
content_helper.getExactContent(gui_pm_content)
%>

<% ngx.print(ui_helper.createHeader(T"Diagnostics Port Mirror", false, true)) %>
<div class="modal-body update">
<%
    local lp = require("web.lp")
    lp.setpath("/www/snippets/")
    lp.include("tabs-diagnostics.lp")
%>
 <form class="form-horizontal" method="post" action="modals/port-mirror-modal.lp">
 <fieldset id="portmirror-configuration-tab">

    <%
	ngx.print(ui_helper.createMessages(message_helper.popMessages()))
        local html = {}
	tinsert(html, ui_helper.createInputSelect(T"Monitored Interface:", "src_intf", src_list, gui_pm_content["src_intf"]))
	tinsert(html, ui_helper.createInputSelect(T"Mirror Interface:", "dst_intf", dst_list ,gui_pm_content["dst_intf"]))
	tinsert(html, ui_helper.createInputSelect(T"Direction:", "direction", dir_list, gui_pm_content["direction"]))
	ngx.print(html)
    %>
    </form>
  </fieldset>
</div>
<% ngx.print(ui_helper.createFooter()) %>
