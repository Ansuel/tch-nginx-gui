<%
-- NG-84920
-- Localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local match, format = string.match, string.format

local tod = require("parental_helper").getTodwifi()
local tod_columns, tod_default, tod_valid, tod_sort_func =
      tod.columns, tod.default, tod.valid, tod.sort_func

local tod_options = {
    tableid     = "tod",
    basepath    = "rpc.wifitod.",
    createMsg   = T"Add New Rule",
    canAdd      = true,
    canDelete   = true,
    canApply    = true,
    canEdit     = true,
    --sorted      = tod_sort_func,
}

local tod_data, tod_helpmsg = post_helper.handleTableQuery(tod_columns, tod_options, nil, tod_default, tod_valid)
%>

<%=ui_helper.createHeader(T"Time of Day") %>
<%=ui_helper.createMessages(message_helper.popMessages()) %>

<div class="modal-body update">
  <%
    local lp = require("web.lp")
    lp.setpath("/www/snippets/")
    lp.include("tabs-tod.lp")
  %>

  <form class="form-horizontal" method="post" action="/modals/tod_wireless-modal.lp">
    <legend><%= T"Time of day wireless control" %></legend>
    <%=
      ui_helper.createTable(tod_columns, tod_data, tod_options, nil, tod_helpmsg)
    %>
    <%if ngx.var.request_method == "POST" and (ngx.req.get_post_args().action == "TABLE-NEW" or ngx.req.get_post_args().action == "TABLE-EDIT") then%>
      <script type="text/javascript">
        var warning = '<div class="control-group"><div style="padding-top: 12px;" class="controls"><span class="alert">'
                      +'<%= T"The Gateway will block/allow all the time if none of the days are selected" %></span></div></div>';
        $('#stoptime').parent().parent().after(warning);
      </script>
    <%end%>
  </form>
</div>

<script type="text/javascript">
    $(function () {
        var opt = {
            theme: 'android-ics light',
            display: 'bubble',
            mode: 'scroller',
            headerText: false,
            timeFormat: 'HH:ii',
            stepMinute: 15
        };
        $("#starttime").mobiscroll().time(opt);
        $("#stoptime").mobiscroll().time(opt);
    });
</script>
<%= ui_helper.createFooter() %>
