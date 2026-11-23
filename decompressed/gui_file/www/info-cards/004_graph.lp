--pretranslated: do not change this file
gettext.textdomain("webui-core")

local ui_helper = require("web.ui_helper")
ngx.print([[
<div class="infocard" id="graphtab">
  <style>
    #graphtab .resources-layout { box-sizing:border-box; padding:12px 14px; }
    #graphtab .resources-range { display:flex; justify-content:flex-end; margin-bottom:10px; }
    #graphtab .resources-range select { width:auto; margin:0; }
    #graphtab .resources-section + .resources-section { margin-top:18px; }
    #graphtab .resources-heading {
      display:grid; grid-template-columns:auto minmax(0,1fr); align-items:baseline; column-gap:10px;
      margin-bottom:6px;
    }
    #graphtab .resources-heading h4 { margin:0; }
    #graphtab .resources-legend {
      display:flex; justify-content:flex-end; flex-wrap:wrap; gap:2px 10px; font-size:12px;
    }
    #graphtab .resources-legend.hide { display:none; }
    #graphtab .resources-legend > span { white-space:nowrap; }
    #graphtab .resources-key {
      display:inline-block; width:12px; height:3px; margin-right:4px; vertical-align:middle; border-radius:2px;
    }
    #graphtab .resources-interface { font-size:12px; white-space:nowrap; }
    #graphtab .resources-interface:empty { display:none; }
    #graphtab .resources-chart { position:relative; height:180px; }
    #graphtab .resources-wan-chart { height:220px; }
    #graphtab .resources-frequency {
      display:flex; justify-content:space-between; gap:4px 12px; flex-wrap:wrap; font-size:12px; margin-top:8px;
    }
    #graphtab .resources-frequency > :last-child { margin-left:auto; }
  </style>
  <div class="smallcard">
]], ui_helper.createCardHeader(T"Resources", nil, nil, nil, nil), [[
    <div class="content">
      <div class="divtable resources-layout">
        <div class="resources-range">
          <select data-resource="chart-range" aria-label="]], T"Graph range", [[">
            <option value="live">]], T"Live · 20 seconds", [[</option>
            <option value="history">]], T"History", [[</option>
          </select>
        </div>
        <section class="resources-section">
          <div class="resources-heading">
            <h4>CPU / RAM</h4>
            <div class="resources-legend">
              <span><i class="resources-key" data-resource="cpu-key" aria-hidden="true"></i>CPU <strong data-resource="resource-cpu">–</strong></span>
              <span><i class="resources-key" data-resource="ram-key" aria-hidden="true"></i>RAM <strong data-resource="resource-ram">–</strong></span>
            </div>
          </div>
          <div class="resources-chart">
            <canvas data-resource="resource-chart" role="img" aria-label="CPU / RAM"></canvas>
          </div>
        </section>
        <section class="resources-section">
          <div class="resources-heading">
            <h4>]], T"WAN Traffic", [[ <span class="resources-interface" data-resource="traffic-interface"></span></h4>
            <div class="resources-legend" data-resource="traffic-reading">
              <span><i class="resources-key" data-resource="rx-key" aria-hidden="true"></i><span data-resource="traffic-download-label">]], T"Download", [[</span> <strong data-resource="traffic-download">–</strong></span>
              <span><i class="resources-key" data-resource="tx-key" aria-hidden="true"></i><span data-resource="traffic-upload-label">]], T"Upload", [[</span> <strong data-resource="traffic-upload">–</strong></span>
            </div>
          </div>
          <div class="resources-chart resources-wan-chart" data-resource="wan-chart-frame">
            <canvas data-resource="wan-chart" role="img" aria-label="]], T"WAN Traffic", [["></canvas>
          </div>
          <div data-resource="traffic-unavailable" class="hide">]], T"No WAN counters available", [[</div>
        </section>
        <div class="resources-frequency">
          <span class="hide" data-resource="historical-source">]], T"Traffic Monitor", [[ · 10 min</span>
        </div>
      </div>
    </div>
  </div>
</div>
<script>
$(function () {
    modgui.initResourceCharts("graphtab", false);
});
</script>
]])
