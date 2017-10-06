<ul class="nav nav-tabs">

<%

gettext.textdomain('webui-voice')
local content_helper = require("web.content_helper")
local ipairs, string = ipairs, string
local items = {
    {"mmpbx-global-modal.lp", T"Global"},
    {"mmpbx-dect-modal.lp", T"DECT"},
    {"mmpbx-contacts-modal.lp", T"Phone Book"},
    {"mmpbx-profile-modal.lp", T"Phone Numbers"},
    {"mmpbx-inoutgoingmap-modal.lp", T"In/Out Mapping"},
    {"mmpbx-service-modal.lp", T"Service"},
    {"mmpbx-log-modal.lp", T"Call Log"},
    {"mmpbx-statistics-modal.lp", T"Quality Log"},
    {"mmpbx-sipdevice-modal.lp", T"Sip Device"},
	{"mmpbx-codec-modal.lp", T"Codec"},
}

local format = string.format
local datamodel = require ("datamodel")
local mmpbx_state, error = datamodel.get("uci.mmpbx.mmpbx.@global.enabled")

if mmpbx_state then
    mmpbx_state = format("%s",mmpbx_state[1].value)
else
    mmpbx_state = "0"
end

-- Retrieving emission state
local emission_content = {
    emission_state = "rpc.mmpbx.dectemission.state",
}
content_helper.getExactContent(emission_content)
emission_state = format("%s", emission_content.emission_state)

local tabs = {}
local session = ngx.ctx.session
if mmpbx_state == "1" then
    for _,v in pairs(items) do
        if session:hasAccess("/modals/" .. v[1]) then
	    if v[1] == "mmpbx-dect-modal.lp" then
		if emission_state == "1" then
		   tabs[#tabs+1] = v
                end
	    else
            tabs[#tabs+1] = v
	    end
        end
    end
elseif session:hasAccess("/modals/mmpbx-global-modal.lp") then
    tabs[#tabs+1] = {"mmpbx-global-modal.lp", T"Global"}
end

local html = {}

local uri = ngx.var.uri
if ngx.var.args and string.len(ngx.var.args) > 0 then
    uri = uri .. "?" .. ngx.var.args
end

html[#html+1] = '<div class="loading-wrapper hide"><img src="/img/spinner.gif" /></div>'

for _,v in ipairs(tabs) do
    local active = ""
    if uri == ("/modals/" .. v[1]) then
        active = "active"
    end

    html[#html+1] = string.format('<li class="%s"><a id ="%s" href="#" class="open-modal" data-remote="/modals/%s">%s</a></li>', active, v[2], v[1], v[2])
end
ngx.print(html)

%>

</ul>

<script>
  $(function(){
    function waiting_action(self) {
        var msg_dst = $(self);
        var busy_msg = $(".loading-wrapper");

        msg_dst.after(busy_msg);
        busy_msg.removeClass("hide");
        busy_msg[0].scrollIntoView();
        $(".modal-body").scrollLeft(0);
    };
    $(document).on("click", "#save-config", function () {
        waiting_action(this);
    });

    $(document).on("click", "table [class*='btn-table-']:not(.disabled)", function () {
        waiting_action(this);
    });

    $(document).on("change", 'table .switch input[type="hidden"]', function (e) {
        var table = $(this).closest("table");
        // Check that we're not editing a line, this is only for when the line is displayed
        if (table.find(".btn-table-cancel").length === 0) {
            waiting_action(this);
        }
    });
  });
</script>
