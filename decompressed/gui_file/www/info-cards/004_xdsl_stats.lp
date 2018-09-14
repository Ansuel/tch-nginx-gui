--pretranslated: do not change this file
 
-- Enable localization
-- NG-92675 implement changes required from the customer
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local ui_helper = require("web.ui_helper")

local find, sub, format = string.find, string.sub, string.format

local contentonly

if ngx.req.get_method() == "GET" then
	contentonly = ngx.req.get_uri_args().contentonly or false
end

local content = {
  status = "Device.DSL.Line.1.Status",
  version = "rpc.xdsl.dslversion",
  max_upstream = "Device.DSL.Line.1.UpstreamMaxBitRate",
  max_downstream = "Device.DSL.Line.1.DownstreamMaxBitRate",
  dsl_linerate_up = "sys.class.xdsl.@line0.UpstreamCurrRate",
  dsl_linerate_down = "sys.class.xdsl.@line0.DownstreamCurrRate",
  dsl_margin_up = "sys.class.xdsl.@line0.UpstreamNoiseMargin",
  dsl_margin_down = "sys.class.xdsl.@line0.DownstreamNoiseMargin",
  dsl_attenuation_up = "sys.class.xdsl.@line0.UpstreamAttenuation",
  dsl_attenuation_down = "sys.class.xdsl.@line0.DownstreamAttenuation",
  dsl_power_up = "sys.class.xdsl.@line0.UpstreamPower",
  dsl_power_down = "sys.class.xdsl.@line0.DownstreamPower",

}


content_helper.getExactContent(content)

  ngx.print('\
\
<div class="infocard span1" id="xdsltab">\
  <div class="smallcard">\
    ');  ngx.print( ui_helper.createCardHeader(T"xDSL Info", nil, nil, nil, nil) ); ngx.print('\
    <div class="content card_bg" data-bg-text="&#xf129;">\
	<div class="divtable">\
	<form class="form-horizontal">\
	<fieldset>');
	
	local basic = {
      span = {
        class = "span3"
      },
    }
    local advanced = {
      group = {
        class = "advanced hide",
      },
      span = {
        class = "span5"
      },
    }
	local advancedshow = {
      group = {
        class = "advanced show",
      },
      span = {
        class = "span5"
      },
    }
	
	local html = {}
	
html[#html + 1] = ui_helper.createLabel(T"Status", content["status"], basic)
html[#html + 1] = ui_helper.createLabel(T"xDSL Version", content["version"], basic)

html[#html + 1] = ui_helper.createLabel(T"Max Upstream Rate", content["max_upstream"] .. " kbps", basic)
html[#html + 1] = ui_helper.createLabel(T"Max Downstream Rate", content["max_downstream"] .. " kbps", basic)

html[#html + 1] = ui_helper.createLabel(T"Upstream Rate", content["dsl_linerate_up"] .. " kbps", basic)
html[#html + 1] = ui_helper.createLabel(T"Downstream Rate", content["dsl_linerate_down"] .. " kbps", basic)

html[#html + 1] = ui_helper.createLabel(T"Noise Margin Upstream", content["dsl_margin_up"] .. " dB", basic)
html[#html + 1] = ui_helper.createLabel(T"Noise Margin Downstream", content["dsl_margin_down"] .. " dB", basic)

html[#html + 1] = ui_helper.createLabel(T"Attenuation Upstream", content["dsl_attenuation_up"] .. " dB", basic)
html[#html + 1] = ui_helper.createLabel(T"Attenuation Downstream", content["dsl_attenuation_down"] .. " dB", basic)

html[#html + 1] = ui_helper.createLabel(T"Power Upstream", content["dsl_power_up"] .. " dBm", basic)
html[#html + 1] = ui_helper.createLabel(T"Power Downstream", content["dsl_power_down"] .. " dBm", basic)


	
	ngx.print(html)
ngx.print('\
	  </fieldset>\
	  </form>\
	  </div>\
    </div>\
  </div>\
</div>\
'); 
