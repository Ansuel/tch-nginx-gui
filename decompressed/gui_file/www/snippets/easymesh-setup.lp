--pretranslated: do not change this file
gettext.textdomain('webui-core')
local setup = require("easymesh_setup")
local mesh = require("easymesh_helper")
local ui = require("web.ui_helper")
local proxy = require("datamodel")
local message, success
if ngx.req.get_method() == "POST" then
  local args = ngx.req.get_post_args()
  if args.action == "SAVE" then
    if args.setup_mode == "initialize" then
      if args.initialize_confirm == "1" or args.experimental == "1" then
        success, message = setup.initialize()
        if success then message = T"Native EasyMesh initialized with the current Wi-Fi credentials. Services remain disabled; select a role below." end
      else
        message = T"Confirm native EasyMesh initialization before continuing."
      end
    elseif args.setup_mode == "role" then
      success, message = setup.set_role(args.mesh_role)
      if success then
        message = args.mesh_role == "off" and T"EasyMesh disabled." or T"EasyMesh role saved. Check topology to verify agent registration."
      end
    else
      message = T"Invalid input"
    end
  end
end
ngx.print(ui.createHeader(T"EasyMesh setup", false, true))
ngx.print('<div class="modal-body">')
local lp = require("web.lp")
lp.setpath("/www/snippets/")
lp.include("tabs-easyMesh.lp")
ngx.print('<form class="form-horizontal" method="post" action="/modals/easy-mesh-configuration.lp?setup=1">')
if message then ngx.print(ui.createAlertBlock(message, {alert={class=success and "alert alert-success" or "alert alert-error"}})) end
if mesh.is_supported() then
  local function value(path)
    local ok, data = pcall(proxy.get, path)
    return ok and data and data[1] and data[1].value
  end
  local agent, controller = value("uci.multiap.agent.enabled"), value("uci.multiap.controller.enabled")
  local role = controller == "1" and "controller" or (agent == "1" and "booster" or "off")
  ngx.print('<input type="hidden" name="setup_mode" value="role">')
  ngx.print(ui.createInputSelect(T"Role", "mesh_role", {{"off", T"Disabled"},
    {"controller", T"Controller and local agent"}, {"booster", T"Ethernet booster (agent only)"}}, role))
  local connected = agent == "1" and value("rpc.multiap.X_000E50_MultiapAgentStatus") or T"Disabled"
  local count = value("rpc.multiap.ExtenderNumberOfEntries")
  if connected and connected ~= "" then ngx.print(ui.createLabel(T"Agent connection", connected)) end
  if count then ngx.print(ui.createLabel(T"Extenders", count)) end
  ngx.print(ui.createAlertBlock(T"Use one controller per Ethernet network. Controller mode keeps the current connection. For a booster, first select the Ethernet uplink in Broadband, then Bridge mode in Internet. Choose DHCP or Static IP on the bridge to retain management access. The bridge disables the local DHCP and RA servers. Wireless backhaul is not configured by this setup.", {alert={class="alert alert-info"}}))
  ngx.print('<p class="mesh-network-links"><a class="btn btn-small" href="#" data-remote="/modals/broadband-modal.lp">',
    T"Broadband", '</a> <a class="btn btn-small" href="#" data-remote="/modals/internet-modal.lp">',
    T"Internet", '</a></p>')
elseif setup.can_initialize() then
  ngx.print('<input type="hidden" name="setup_mode" value="initialize">')
  ngx.print(ui.createAlertBlock(T"Native EasyMesh components and a compatible configuration template were detected. Initialization copies the current main Wi-Fi credentials using this device's own firmware files. Services remain disabled and routing stays unchanged until you select a role. Verify agent registration and credential propagation after setup.", {alert={class="alert alert-info"}}))
  ngx.print(ui.createSwitch(T"Initialize native EasyMesh", "initialize_confirm", "0"))
else
  ngx.print(ui.createAlertBlock(T"Native EasyMesh is unavailable on this firmware.", {alert={class="alert alert-warning"}}))
end
ngx.print('</form></div>')
ngx.print(ui.createFooter())
