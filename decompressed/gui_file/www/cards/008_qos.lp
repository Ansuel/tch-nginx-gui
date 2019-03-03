--pretranslated: do not change this file

-- Enable localization
gettext.textdomain('webui-qos')

local format = string.format

local modal_link = nil

local session = ngx.ctx.session
if session:hasAccess("/modals/qos-queue-modal.lp") and session:hasAccess("/modals/qos-classify-modal.lp") then
 modal_link = "/modals/qos-queue-modal.lp"
end

local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")

-- Menu display information (policy classgroup name MUST match value in qos config)
local dataQoS = {
    numQueues   = "uci.qos.classNumberOfEntries",
    numClassify = "uci.qos.classifyNumberOfEntries",
}
content_helper.getExactContent(dataQoS)

ngx.print('\
<div class="span3">\
    <div class="smallcard" data-aos="zoom-in" data-aos-anchor-placement="center-bottom" data-aos-easing="ease-in-back">\
        '); ngx.print( ui_helper.createCardHeader(T"QoS", modal_link) ); ngx.print('\
        <div class="content card_bg" data-bg-text="&#xf362;">\
		<div class="divtable">\
			');
                local html = {}
				html[#html + 1] = "<span class=\"simple-desc\">"
                html[#html + 1] = '<i " class="fas fa-list-ul" aria-hidden="true" href="#">&nbsp</i>'
                html[#html + 1] = format(N("<strong>%s queue(s)</strong> active"), dataQoS.numQueues)
				html[#html + 1] = "</span>"
				html[#html + 1] = "<span class=\"simple-desc\">"
                html[#html + 1] = '<i " class="fas fa-list-ul" aria-hidden="true" href="#">&nbsp</i>'
                html[#html + 1] = format(N("<strong>%s classify rule(s)</strong> active"), dataQoS.numClassify)
				html[#html + 1] = "</span>"
                ngx.print (html)
            ngx.print('\
        </div>\
		</div>\
    </div>\
</div>\
');
