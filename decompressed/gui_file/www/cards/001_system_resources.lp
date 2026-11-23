--pretranslated: do not change this file
gettext.textdomain("webui-core")

local ui_helper = require("web.ui_helper")
local modal = "/modals/traffic-monitor.lp"
if not ngx.ctx.session:hasAccess(modal) then return end
-- The firmware helper also uses its title as an unquoted HTML ID.
local header = table.concat(ui_helper.createCardHeader("system-resources", modal, nil, nil, {
    header = {["data-id"] = "device-modal"},
    div = {["data-id"] = "device-modal"},
}))
header = header:gsub(">system%-resources</p>", function()
    return ">" .. T"System resources" .. "</p>"
end, 1)
ngx.print([[
<div class="span3" id="system-resources-card">
  <style>
    #system-resources-card .resources-summary {
      display:flex; flex-direction:column; gap:3px; height:100%;
      font-size:12px; line-height:1.15; font-variant-numeric:tabular-nums;
    }
    #system-resources-card .resources-row {
      display:flex; flex-wrap:wrap; align-items:baseline; justify-content:space-between;
      gap:2px 8px;
    }
    #system-resources-card .resources-row > span { white-space:nowrap; }
    #system-resources-card .resources-details { font-size:11px; }
    #system-resources-card .resources-charts { display:flex; gap:10px; flex:1; min-height:42px; }
    #system-resources-card .resources-chart { display:flex; flex-direction:column; flex:1; min-width:0; }
    #system-resources-card .resources-plot { position:relative; flex:1; min-height:28px; margin-top:2px; }
    #system-resources-card .resources-lan { position:absolute; inset:0; }
    #system-resources-card .resources-caption { font-size:11px; white-space:nowrap; }
  </style>
  <div class="smallcard" data-aos="zoom-in" data-aos-anchor-placement="center-bottom" data-aos-easing="ease-in-back">
]], header, [[
    <div class="content card_bg">
      <div class="divtable resources-summary">
        <div class="resources-row">
          <span><strong>RAM <span data-bind="text: mem_used_mib"></span>/<span data-bind="text: mem_total"></span></strong></span>
          <span><strong data-bind="text: mem_pct"></strong></span>
        </div>
        <div class="resources-row resources-details" title="MiB">
          <span>]], T"Available", [[ <strong data-bind="text: mem_available_mib"></strong></span>
          <span>]], T"Free", [[ <strong data-bind="text: mem_free_mib"></strong></span>
          <span>]], T"Cache", [[ <strong data-bind="text: mem_cache_mib"></strong></span>
        </div>
        <div class="resources-row resources-details" title="]], T"Available space", [[ / ]], T"Total", [[">
          <span>]], T"Storage", [[ <strong data-bind="text: storage_internal_capacity"></strong></span>
          <span>USB <strong data-bind="text: storage_usb_capacity"></strong></span>
        </div>
        <div class="resources-charts">
          <div class="resources-chart">
            <div class="resources-caption">
              <span style="border-bottom:2px solid #3487c9">CPU <strong data-resource="resource-cpu">–</strong></span>
              <span style="border-bottom:2px solid #ad68bd">RAM</span>
            </div>
            <div class="resources-plot">
              <canvas data-resource="resource-chart" role="img" aria-label="CPU / RAM"></canvas>
            </div>
          </div>
          <div class="resources-chart">
            <div class="resources-caption">
              br-lan <span data-resource="traffic-download-label" class="hide">RX</span>
              <span data-resource="traffic-upload-label" class="hide">TX</span>
              <span aria-hidden="true" style="color:#379962">↓</span>
              <span aria-hidden="true" style="color:#df7951">↑</span>
            </div>
            <div class="resources-plot">
              <div data-resource="wan-chart-frame" class="resources-lan">
                <canvas data-resource="wan-chart" role="img" aria-label="br-lan RX / TX"></canvas>
              </div>
              <span data-resource="traffic-unavailable" class="hide">]], T"Unavailable", [[</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</div>
<script>
$(function () {
    modgui.createAjaxUpdateCard("system-resources-card", "/ajax/cpuload.lua", "SystemResourcesCardInterval", 5000);
    modgui.initResourceCharts("system-resources-card", true);
});
</script>
]])
