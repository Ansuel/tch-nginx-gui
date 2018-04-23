<%
-- Enable localization
gettext.textdomain('webui-qos')

local format = string.format

local session = ngx.ctx.session
if session:hasAccess("/modals/qos-queue-modal.lp") and session:hasAccess("/modals/qos-classify-modal.lp") then

local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")

-- Menu display information (policy classgroup name MUST match value in qos config)
local dataQoS = {
    numQueues   = "uci.qos.classNumberOfEntries",
    numClassify = "uci.qos.classifyNumberOfEntries",
}
content_helper.getExactContent(dataQoS)

%>

<div class="span3">
    <div class="smallcard" data-aos="fade-up" data-aos-anchor-placement="center-bottom" data-aos-easing="ease-in-back">
        <%= ui_helper.createCardHeader(T"QoS", "modals/qos-queue-modal.lp") %>
        <div class="content card_bg" data-bg-text="&#xf0ec;">
		<div class="divtable">
            <%
                local html = {}
                html[#html + 1] = format(N("<p class='subinfos'><strong>%s queue(s)</strong> active</p>"), dataQoS.numQueues)
                html[#html + 1] = format(N("<p class='subinfos'><strong>%s classify rule(s)</strong> active</p>"), dataQoS.numClassify)
                ngx.print (html)
            %>
        </div>
		</div>
    </div>
</div>

<%
end
%>
