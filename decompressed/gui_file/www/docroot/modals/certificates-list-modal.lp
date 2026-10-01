--pretranslated: do not change this file
 
--pretranslated: do not change this file
-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local ngx, string = ngx, string
local pairingNumberOfEntries = proxy.get("sys.generic_app.PairingNumberOfEntries")
pairingNumberOfEntries = pairingNumberOfEntries and pairingNumberOfEntries[1].value or ""
local pairing = proxy.get("sys.generic_app.Pairing.")
pairing = pairing and pairing or ""
local name, certificates, indexes = {}, {}, {}
local untaint = string.untaint
local json = require("dkjson")

if pairing ~= "" then
  for _, list in ipairs (pairing) do
    if list.param == "Name" then
      indexes[#indexes + 1] = string.match(list.path,"%d+")
      name[#name + 1] = list.value
    end
    if list.param == "Certificate" then
      certificates[#certificates + 1] = list.value
    end
  end
end

if ngx.var.request_method == "POST" then
  local postargs = ngx.req.get_post_args()
  local success = proxy.del("sys.generic_app.Pairing." ..untaint(postargs.index) ..".")
  if success then
    proxy.apply()
  end
  ngx.print(json.encode(success))
  ngx.exit(ngx.HTTP_OK)
end
  ngx.print('\
');  ngx.print(ui_helper.createHeader(T"Details for paired devices", false, false))   ngx.print('\
\
<div class="modal-body update">\
  <fieldset>\
    <div id="success_msg" class="alert  hide alert-success">');  ngx.print(T"Changes saved successfully"); ngx.print('</div>\
    <div id="error_msg" class="alert  hide alert-error">');  ngx.print(T"The request could not be performed due to some error"); ngx.print('</div>\
    <legend>');  ngx.print( T"Certificates Lists" ); ngx.print('</legend>\
    <form class="form-horizontal" method="post" id="certificate_form" action="');  ngx.print(ngx.var.request_uri); ngx.print('">\
      <table id="certificateslist" style="width:100%;">\
        <tr style="text-align:left;font-size:15px;">\
          <th>');  ngx.print(T"Name"); ngx.print('</th>\
          <th>');  ngx.print(T"Certificates"); ngx.print('</th>\
        </tr><br>\
        <tbody>\
          ');  if pairingNumberOfEntries ~= 0 then   ngx.print('\
            ');  for index, names  in ipairs (name) do   ngx.print('\
              <tr id="row');  ngx.print(indexes[index]); ngx.print('"class="table table-striped" style="background-color:#f9f9f9;word-break:break-all;">\
                <td style="width:12%;">');  ngx.print(names); ngx.print('</td>\
                <td style="width:80%;">');  ngx.print(certificates[index]); ngx.print('</td>\
                <td>\
                  <div class="btn btn-mini tooltip-on" data-placement="top" data-original-title="Delete">\
                    <i class="icon-remove-sign icon-large" onclick="deleterow(');  ngx.print(indexes[index]); ngx.print(');"></i>\
                  </div>\
                </td>\
              </tr>\
            ');  end  ngx.print('\
          ');  end  ngx.print('\
        </tbody>\
      </table>\
    </form>\
  </fieldset>\
</div>\
\
<script>\
function deleterow(index) {\
  var csrftoken = $("meta[name=CSRFtoken]").attr("content");\
  var params = [];\
  params.push ({\
    name : "index",\
    value : index\
  },\
  {\
    name : "CSRFtoken",\
    value : csrftoken\
  });\
  $.post($("#certificate_form").attr("action"), params, function(data) {\
  if (data == "true"){\
    $("#certificateslist tr#row"+index).remove();\
    $("#success_msg").show(300);\
  }\
  else {\
    $("#error_msg").show(300);\
  }\
  $(".modal-body").scrollTop(0);\
  });\
}\
</script>\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
'); 