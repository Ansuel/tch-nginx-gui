--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local format = string.format
local table = table

local getargs = ngx.req.get_uri_args()
if getargs.action == "GET_BITS" then
  local xdsl_BitLoading = "sys.class.xdsl.@line0.BitLoading"
  local xdsl_BitLoading1 = "sys.class.xdsl.@line1.BitLoading"
  local bvalue = proxy.get(xdsl_BitLoading)
  if bvalue ~= nil and bvalue[1] ~= nil then
    xdsl_BitLoading = bvalue[1].value
  end
  local html = {}
  html[#html+1] ='<div style="max-width:880px;overflow-x:auto"><small>'
  html[#html+1] =ui_helper.createBitLoadHistogram(xdsl_BitLoading)
  if getargs.show_line_one == "1" then
    html[#html+1]=format('<legend>%s</legend>', T"DSL Bit Loading (Line 1)")
    html[#html+1]=ui_helper.createBitLoadHistogram(xdsl_BitLoading1)
  end
  html[#html+1] ="</small></div>"
  ngx.print(html)
  ngx.exit(ngx.HTTP_OK)
end
-- Loading the advanced content by using ajax call, we are able to save around 2 seconds from total page loading time.
if getargs.action == "GET_ADVANCED_DATA" then
local content = {
    firmware_version = "sys.class.xdsl.@line0.FirmwareVersion",
    xdsl_ginp_rxqueue_ds = "sys.class.xdsl.@line0.DownstreamGINPRxQueue",
    xdsl_ginp_rxqueue_us = "sys.class.xdsl.@line0.UpstreamGINPRxQueue",
    xdsl_ginp_txqueue_ds = "sys.class.xdsl.@line0.DownstreamGINPTxQueue",
    xdsl_ginp_txqueue_us = "sys.class.xdsl.@line0.UpstreamGINPTxQueue",
    xdsl_ginp_lookback_ds = "sys.class.xdsl.@line0.DownstreamGINPLookBack",
    xdsl_ginp_lookback_us = "sys.class.xdsl.@line0.UpstreamGINPLookBack",
    xdsl_ginp_rrcbits_ds = "sys.class.xdsl.@line0.DownstreamGINPRRCBits",
    xdsl_ginp_rrcbits_us = "sys.class.xdsl.@line0.UpstreamGINPRRCBits",
    xdsl_ginp_rtxtx_ds = "sys.class.xdsl.@line0.DownstreamGINPRTxTx",
    xdsl_ginp_rtxtx_us = "sys.class.xdsl.@line0.UpstreamGINPRTxTx",
    xdsl_ginp_rtxc_ds = "sys.class.xdsl.@line0.DownstreamGINPRTxC",
    xdsl_ginp_rtxc_us = "sys.class.xdsl.@line0.UpstreamGINPRTxC",
    xdsl_ginp_rtxuc_ds = "sys.class.xdsl.@line0.DownstreamGINPRTxUC",
    xdsl_ginp_rtxuc_us = "sys.class.xdsl.@line0.UpstreamGINPRTxUC",
    xdsl_ginp_leftrs_ds = "sys.class.xdsl.@line0.DownstreamGINPLEFTRS",
    xdsl_ginp_leftrs_us = "sys.class.xdsl.@line0.UpstreamGINPLEFTRS",
    xdsl_ginp_mineftr_ds = "sys.class.xdsl.@line0.DownstreamGINPMinEFTR",
    xdsl_ginp_mineftr_us = "sys.class.xdsl.@line0.UpstreamGINPMinEFTR",
    xdsl_ginp_errfreebits_ds = "sys.class.xdsl.@line0.DownstreamGINPErrFreeBits",
    xdsl_ginp_errfreebits_us = "sys.class.xdsl.@line0.UpstreamGINPErrFreeBits",
    xdsl_ginp_status = "sys.class.xdsl.@line0.GINPStatus",
    xdsl_vectoring_directionmode = "sys.class.xdsl.@line0.VectoringDirectionMode",
    xdsl_vectoring_rxbitswapmode = "sys.class.xdsl.@line0.VectoringRxBitSwapMode",
    xdsl_vectoring_disablevnmode= "sys.class.xdsl.@line0.VectoringDisableVNMode",
    xdsl_vectoring_vceaddress = "sys.class.xdsl.@line0.VectoringVceAddress",
    xdsl_vectoring_cntespktsend = "sys.class.xdsl.@line0.VectoringCntESPktSend",
    xdsl_vectoring_cntespktdrop = "sys.class.xdsl.@line0.VectoringCntESPktDrop",
    xdsl_vectoring_cntesstatsend = "sys.class.xdsl.@line0.VectoringCntESStatSend",
    xdsl_vectoring_cntesstatdrop = "sys.class.xdsl.@line0.VectoringCntESStatDrop",
    xdsl_framing_upstream_r = "sys.class.xdsl.@line0.UpstreamFramingR",
    xdsl_framing_downstream_r = "sys.class.xdsl.@line0.DownstreamFramingR",
    xdsl_framing_upstream_s = "sys.class.xdsl.@line0.UpstreamFramingS",
    xdsl_framing_downstream_s = "sys.class.xdsl.@line0.DownstreamFramingS",
    xdsl_framing_upstream_d = "sys.class.xdsl.@line0.UpstreamFramingD",
    xdsl_framing_downstream_d = "sys.class.xdsl.@line0.DownstreamFramingD",
    xdsl_framing_upstream_l = "sys.class.xdsl.@line0.UpstreamFramingL",
    xdsl_framing_downstream_l = "sys.class.xdsl.@line0.DownstreamFramingL",
    xdsl_framing_upstream_n = "sys.class.xdsl.@line0.UpstreamFramingN",
    xdsl_framing_downstream_n = "sys.class.xdsl.@line0.DownstreamFramingN",
    xdsl_counter_upstream_or = "sys.class.xdsl.@line0.UpstreamOR",
    xdsl_counter_downstream_or = "sys.class.xdsl.@line0.DownstreamOR",
    xdsl_counter_upstream_inp = "sys.class.xdsl.@line0.UpstreamINP",
    xdsl_counter_downstream_inp = "sys.class.xdsl.@line0.DownstreamINP",
    xdsl_counter_upstream_delay = "sys.class.xdsl.@line0.UpstreamDelay",
    xdsl_counter_downstream_delay = "sys.class.xdsl.@line0.DownstreamDelay",
    xdsl_counter_upstream_trellis = "sys.class.xdsl.@line0.UpstreamTrellis",
    xdsl_counter_downstream_trellis = "sys.class.xdsl.@line0.DownstreamTrellis",
}
content_helper.getExactContent(content)

local content1 = {
    dsl_bonding_support = "sys.class.xdsl.@line1.BondingSupport",
    firmware_version = "sys.class.xdsl.@line1.FirmwareVersion",
    xdsl_ginp_rxqueue_ds = "sys.class.xdsl.@line1.DownstreamGINPRxQueue",
    xdsl_ginp_rxqueue_us = "sys.class.xdsl.@line1.UpstreamGINPRxQueue",
    xdsl_ginp_txqueue_ds = "sys.class.xdsl.@line1.DownstreamGINPTxQueue",
    xdsl_ginp_txqueue_us = "sys.class.xdsl.@line1.UpstreamGINPTxQueue",
    xdsl_ginp_lookback_ds = "sys.class.xdsl.@line1.DownstreamGINPLookBack",
    xdsl_ginp_lookback_us = "sys.class.xdsl.@line1.UpstreamGINPLookBack",
    xdsl_ginp_rrcbits_ds = "sys.class.xdsl.@line1.DownstreamGINPRRCBits",
    xdsl_ginp_rrcbits_us = "sys.class.xdsl.@line1.UpstreamGINPRRCBits",
    xdsl_ginp_rtxtx_ds = "sys.class.xdsl.@line1.DownstreamGINPRTxTx",
    xdsl_ginp_rtxtx_us = "sys.class.xdsl.@line1.UpstreamGINPRTxTx",
    xdsl_ginp_rtxc_ds = "sys.class.xdsl.@line1.DownstreamGINPRTxC",
    xdsl_ginp_rtxc_us = "sys.class.xdsl.@line1.UpstreamGINPRTxC",
    xdsl_ginp_rtxuc_ds = "sys.class.xdsl.@line1.DownstreamGINPRTxUC",
    xdsl_ginp_rtxuc_us = "sys.class.xdsl.@line1.UpstreamGINPRTxUC",
    xdsl_ginp_leftrs_ds = "sys.class.xdsl.@line1.DownstreamGINPLEFTRS",
    xdsl_ginp_leftrs_us = "sys.class.xdsl.@line1.UpstreamGINPLEFTRS",
    xdsl_ginp_mineftr_ds = "sys.class.xdsl.@line1.DownstreamGINPMinEFTR",
    xdsl_ginp_mineftr_us = "sys.class.xdsl.@line1.UpstreamGINPMinEFTR",
    xdsl_ginp_errfreebits_ds = "sys.class.xdsl.@line1.DownstreamGINPErrFreeBits",
    xdsl_ginp_errfreebits_us = "sys.class.xdsl.@line1.UpstreamGINPErrFreeBits",
    xdsl_ginp_status = "sys.class.xdsl.@line1.GINPStatus",
    xdsl_vectoring_directionmode = "sys.class.xdsl.@line1.VectoringDirectionMode",
    xdsl_vectoring_rxbitswapmode = "sys.class.xdsl.@line1.VectoringRxBitSwapMode",
    xdsl_vectoring_disablevnmode= "sys.class.xdsl.@line1.VectoringDisableVNMode",
    xdsl_vectoring_vceaddress = "sys.class.xdsl.@line1.VectoringVceAddress",
    xdsl_vectoring_cntespktsend = "sys.class.xdsl.@line1.VectoringCntESPktSend",
    xdsl_vectoring_cntespktdrop = "sys.class.xdsl.@line1.VectoringCntESPktDrop",
    xdsl_vectoring_cntesstatsend = "sys.class.xdsl.@line1.VectoringCntESStatSend",
    xdsl_vectoring_cntesstatdrop = "sys.class.xdsl.@line1.VectoringCntESStatDrop",
    xdsl_framing_upstream_r = "sys.class.xdsl.@line1.UpstreamFramingR",
    xdsl_framing_downstream_r = "sys.class.xdsl.@line1.DownstreamFramingR",
    xdsl_framing_upstream_s = "sys.class.xdsl.@line1.UpstreamFramingS",
    xdsl_framing_downstream_s = "sys.class.xdsl.@line1.DownstreamFramingS",
    xdsl_framing_upstream_d = "sys.class.xdsl.@line1.UpstreamFramingD",
    xdsl_framing_downstream_d = "sys.class.xdsl.@line1.DownstreamFramingD",
    xdsl_framing_upstream_l = "sys.class.xdsl.@line1.UpstreamFramingL",
    xdsl_framing_downstream_l = "sys.class.xdsl.@line1.DownstreamFramingL",
    xdsl_framing_upstream_n = "sys.class.xdsl.@line1.UpstreamFramingN",
    xdsl_framing_downstream_n = "sys.class.xdsl.@line1.DownstreamFramingN",
    xdsl_counter_upstream_or = "sys.class.xdsl.@line1.UpstreamOR",
    xdsl_counter_downstream_or = "sys.class.xdsl.@line1.DownstreamOR",
    xdsl_counter_upstream_inp = "sys.class.xdsl.@line1.UpstreamINP",
    xdsl_counter_downstream_inp = "sys.class.xdsl.@line1.DownstreamINP",
    xdsl_counter_upstream_delay = "sys.class.xdsl.@line1.UpstreamDelay",
    xdsl_counter_downstream_delay = "sys.class.xdsl.@line1.DownstreamDelay",
    xdsl_counter_upstream_trellis = "sys.class.xdsl.@line1.UpstreamTrellis",
    xdsl_counter_downstream_trellis = "sys.class.xdsl.@line1.DownstreamTrellis",
}

  local bstats = proxy.get("sys.class.xdsl.@line0.BondingSupport")
  if bstats ~= nil and bstats[1].value == 1 then
    content_helper.getExactContent(content1)
  end
    local html = {}
    html[#html + 1] = '<fieldset id="diagnostics-xdsl-framing" class="advanced hide">'
    html[#html + 1] = '<legend>'.. T"Framing parameters"..'</legend><form class="form-horizontal">'
    local iconUp = "<i class=\"icon-upload icon-large gray\"></i> "
    local iconDown = "<i class=\"icon-download icon-large gray\"></i>"
    local trellisus, trellisds
    if content["xdsl_counter_upstream_trellis"] then
      trellisus = "On"
    else
      trellisus = "Off"
    end
    if content["xdsl_counter_downstream_trellis"] then
      trellisds = "On"
    else
      trellisds = "Off"
    end
      html[#html + 1] = ui_helper.createLabel( T"R", format("%s %s %s %s", iconUp, T(content["xdsl_framing_upstream_r"]), iconDown, T(content["xdsl_framing_downstream_r"])) )
      html[#html + 1] = ui_helper.createLabel( T"S", format("%s %s %s %s", iconUp, T(content["xdsl_framing_upstream_s"]), iconDown, T(content["xdsl_framing_downstream_s"])) )
      html[#html + 1] = ui_helper.createLabel( T"D", format("%s %s %s %s", iconUp, T(content["xdsl_framing_upstream_d"]), iconDown, T(content["xdsl_framing_downstream_d"])) )
      html[#html + 1] = ui_helper.createLabel( T"L", format("%s %s %s %s", iconUp, T(content["xdsl_framing_upstream_l"]), iconDown, T(content["xdsl_framing_downstream_l"])) )
      html[#html + 1] = ui_helper.createLabel( T"N", format("%s %s %s %s", iconUp, T(content["xdsl_framing_upstream_n"]), iconDown, T(content["xdsl_framing_downstream_n"])) )
      html[#html + 1] = ui_helper.createLabel( T"OR", format("%s %s %s %s", iconUp, T(content["xdsl_counter_upstream_or"]), iconDown, T(content["xdsl_counter_downstream_or"])) )
      html[#html + 1] = ui_helper.createLabel( T"INP", format("%s %s %s %s", iconUp, T(content["xdsl_counter_upstream_inp"]), iconDown, T(content["xdsl_counter_downstream_inp"])) )
      html[#html + 1] = ui_helper.createLabel( T"Delay", format("%s %s %s %s", iconUp, T(content["xdsl_counter_upstream_delay"]), iconDown, T(content["xdsl_counter_downstream_delay"])) )
      html[#html + 1] = ui_helper.createLabel( T"Trellis", format("%s %s %s %s", iconUp, T(trellisus), iconDown, T(trellisds)) )
      html[#html + 1] = '</form></fieldset><fieldset id="diagnostics-xdsl-ginp" class="advanced hide">'
      html[#html + 1] = '<legend>' .. T"G.INP stats" .. '</legend><form class="form-horizontal">'
      local iconUp = "<i class=\"icon-upload icon-large gray\"></i> "
      local iconDown = "<i class=\"icon-download icon-large gray\"></i>"
      local statusIcon
      if content["xdsl_ginp_status"] == "0" then
        statusIcon = "<div class=\"light red\"></div>"
      else
        statusIcon = "<div class=\"light green\"></div>"
      end
      html[#html + 1] = ui_helper.createLabel( T"Status", statusIcon )
      html[#html + 1] = ui_helper.createLabel( T"ReXmt", format("%s %s %s %s", iconUp, T(content["xdsl_ginp_rtxtx_us"]), iconDown, T(content["xdsl_ginp_rtxtx_ds"])) )
      html[#html + 1] = ui_helper.createLabel( T"ReXmtCor", format("%s %s %s %s", iconUp, T(content["xdsl_ginp_rtxc_us"]), iconDown, T(content["xdsl_ginp_rtxc_ds"])) )
      html[#html + 1] = ui_helper.createLabel( T"ReXmtUnc", format("%s %s %s %s", iconUp, T(content["xdsl_ginp_rtxuc_us"]), iconDown, T(content["xdsl_ginp_rtxuc_ds"])) )
      html[#html + 1] = ui_helper.createLabel( T"RxQueue", format("%s %s %s %s", iconUp, T(content["xdsl_ginp_rxqueue_us"]), iconDown, T(content["xdsl_ginp_rxqueue_ds"])) )
      html[#html + 1] = ui_helper.createLabel( T"TxQueue", format("%s %s %s %s", iconUp, T(content["xdsl_ginp_txqueue_us"]), iconDown, T(content["xdsl_ginp_txqueue_ds"])) )
      html[#html + 1] = ui_helper.createLabel( T"LookBack", format("%s %s %s %s", iconUp, T(content["xdsl_ginp_lookback_us"]), iconDown, T(content["xdsl_ginp_lookback_ds"])) )
      html[#html + 1] = ui_helper.createLabel( T"RRCBits", format("%s %s %s %s", iconUp, T(content["xdsl_ginp_rrcbits_us"]), iconDown, T(content["xdsl_ginp_rrcbits_ds"])) )
      html[#html + 1] = ui_helper.createLabel( T"LEFTRS", format("%s %s %s %s", iconUp, T(content["xdsl_ginp_leftrs_us"]), iconDown, T(content["xdsl_ginp_leftrs_ds"])) )
      html[#html + 1] = ui_helper.createLabel( T"minEFTR", format("%s %s %s %s", iconUp, T(content["xdsl_ginp_mineftr_us"]), iconDown, T(content["xdsl_ginp_mineftr_ds"])) )
      html[#html + 1] = ui_helper.createLabel( T"ErrFreeBits", format("%s %s %s %s", iconUp, T(content["xdsl_ginp_errfreebits_us"]), iconDown, T(content["xdsl_ginp_errfreebits_ds"])) )
      html[#html + 1] = '</form></fieldset><fieldset id="diagnostics-xdsl-vectoring" class="advanced hide">'
      html[#html + 1] = '<legend>' .. T"Vectoring stats" .. '</legend><form class="form-horizontal">'
      html[#html + 1] = ui_helper.createLabel( T"ErrS Packet Send", T(content["xdsl_vectoring_cntespktsend"]))
      html[#html + 1] = ui_helper.createLabel( T"ErrS Packet Drop", T(content["xdsl_vectoring_cntespktdrop"]))
      html[#html + 1] = ui_helper.createLabel( T"ErrS Stat Send", T(content["xdsl_vectoring_cntesstatsend"]))
      html[#html + 1] = ui_helper.createLabel( T"ErrS Stat Drop", T(content["xdsl_vectoring_cntesstatdrop"]))
      html[#html + 1] = ui_helper.createLabel( T"Direction Mode", T(content["xdsl_vectoring_directionmode"]))
      html[#html + 1] = ui_helper.createLabel( T"Rx BitSwap Mode", T(content["xdsl_vectoring_rxbitswapmode"]))
      html[#html + 1] = ui_helper.createLabel( T"Disable VN Mode", T(content["xdsl_vectoring_disablevnmode"]))
      html[#html + 1] = ui_helper.createLabel( T"VCE Address", T(content["xdsl_vectoring_vceaddress"]))
      html[#html + 1] = '</form></fieldset>'
      ngx.print(html)
      ngx.exit(ngx.HTTP_OK)
end

local columns ={}
local columns1 = {}

for i=1, 16 do
    columns[i]={}
    columns1[i]={}
end

columns[1][1] = T"Upstream FEC"
columns[2][1] = T"Downstream FEC"
columns[3][1] = T"Upstream CRC"
columns[4][1] = T"Downstream CRC"
columns[5][1] = T"Upstream ES"
columns[6][1] = T"Downstream ES"
columns[7][1] = T"Upstream SES"
columns[8][1] = T"Downstream SES"
columns[9][1] = T"Upstream UAS"
columns[10][1] = T"Downstream UAS"
columns[11][1] = T"Upstream LOS"
columns[12][1] = T"Downstream LOS"
columns[13][1] = T"Upstream LOF"
columns[14][1] = T"Downstream LOF"
columns[15][1] = T"Upstream LOM"
columns[16][1] = T"Downstream LOM"

columns[1][2] = "sys.class.xdsl.@line0.UpstreamFECTotal"
columns[2][2] = "sys.class.xdsl.@line0.DownstreamFECTotal"
columns[3][2] = "sys.class.xdsl.@line0.UpstreamCRCTotal"
columns[4][2] = "sys.class.xdsl.@line0.DownstreamCRCTotal"
columns[5][2] = "sys.class.xdsl.@line0.UpstreamESTotal"
columns[6][2] = "sys.class.xdsl.@line0.DownstreamESTotal"
columns[7][2] = "sys.class.xdsl.@line0.UpstreamSESTotal"
columns[8][2] = "sys.class.xdsl.@line0.DownstreamSESTotal"
columns[9][2] = "sys.class.xdsl.@line0.UpstreamUASTotal"
columns[10][2] = "sys.class.xdsl.@line0.DownstreamUASTotal"
columns[11][2] = "sys.class.xdsl.@line0.UpstreamLOSTotal"
columns[12][2] = "sys.class.xdsl.@line0.DownstreamLOSTotal"
columns[13][2] = "sys.class.xdsl.@line0.UpstreamLOFTotal"
columns[14][2] = "sys.class.xdsl.@line0.DownstreamLOFTotal"
columns[15][2] = "sys.class.xdsl.@line0.UpstreamLOMTotal"
columns[16][2] = "sys.class.xdsl.@line0.DownstreamLOMTotal"

columns[1][3] = "sys.class.xdsl.@line0.UpstreamFECCurrentQuarter"
columns[2][3] = "sys.class.xdsl.@line0.DownstreamFECCurrentQuarter"
columns[3][3] = "sys.class.xdsl.@line0.UpstreamCRCCurrentQuarter"
columns[4][3] = "sys.class.xdsl.@line0.DownstreamCRCCurrentQuarter"
columns[5][3] = "sys.class.xdsl.@line0.UpstreamESCurrentQuarter"
columns[6][3] = "sys.class.xdsl.@line0.DownstreamESCurrentQuarter"
columns[7][3] = "sys.class.xdsl.@line0.UpstreamSESCurrentQuarter"
columns[8][3] = "sys.class.xdsl.@line0.DownstreamSESCurrentQuarter"
columns[9][3] = "sys.class.xdsl.@line0.UpstreamUASCurrentQuarter"
columns[10][3] = "sys.class.xdsl.@line0.DownstreamUASCurrentQuarter"
columns[11][3] = "sys.class.xdsl.@line0.UpstreamLOSCurrentQuarter"
columns[12][3] = "sys.class.xdsl.@line0.DownstreamLOSCurrentQuarter"
columns[13][3] = "sys.class.xdsl.@line0.UpstreamLOFCurrentQuarter"
columns[14][3] = "sys.class.xdsl.@line0.DownstreamLOFCurrentQuarter"
columns[15][3] = "sys.class.xdsl.@line0.UpstreamLOMCurrentQuarter"
columns[16][3] = "sys.class.xdsl.@line0.DownstreamLOMCurrentQuarter"

columns[1][4] = "sys.class.xdsl.@line0.UpstreamFECPreviousQuarter"
columns[2][4] = "sys.class.xdsl.@line0.DownstreamFECPreviousQuarter"
columns[3][4] = "sys.class.xdsl.@line0.UpstreamCRCPreviousQuarter"
columns[4][4] = "sys.class.xdsl.@line0.DownstreamCRCPreviousQuarter"
columns[5][4] = "sys.class.xdsl.@line0.UpstreamESPreviousQuarter"
columns[6][4] = "sys.class.xdsl.@line0.DownstreamESPreviousQuarter"
columns[7][4] = "sys.class.xdsl.@line0.UpstreamSESPreviousQuarter"
columns[8][4] = "sys.class.xdsl.@line0.DownstreamSESPreviousQuarter"
columns[9][4] = "sys.class.xdsl.@line0.UpstreamUASPreviousQuarter"
columns[10][4] = "sys.class.xdsl.@line0.DownstreamUASPreviousQuarter"
columns[11][4] = "sys.class.xdsl.@line0.UpstreamLOSPreviousQuarter"
columns[12][4] = "sys.class.xdsl.@line0.DownstreamLOSPreviousQuarter"
columns[13][4] = "sys.class.xdsl.@line0.UpstreamLOFPreviousQuarter"
columns[14][4] = "sys.class.xdsl.@line0.DownstreamLOFPreviousQuarter"
columns[15][4] = "sys.class.xdsl.@line0.UpstreamLOMPreviousQuarter"
columns[16][4] = "sys.class.xdsl.@line0.DownstreamLOMPreviousQuarter"

columns[1][5] = "sys.class.xdsl.@line0.UpstreamFECCurrentDay"
columns[2][5] = "sys.class.xdsl.@line0.DownstreamFECCurrentDay"
columns[3][5] = "sys.class.xdsl.@line0.UpstreamCRCCurrentDay"
columns[4][5] = "sys.class.xdsl.@line0.DownstreamCRCCurrentDay"
columns[5][5] = "sys.class.xdsl.@line0.UpstreamESCurrentDay"
columns[6][5] = "sys.class.xdsl.@line0.DownstreamESCurrentDay"
columns[7][5] = "sys.class.xdsl.@line0.UpstreamSESCurrentDay"
columns[8][5] = "sys.class.xdsl.@line0.DownstreamSESCurrentDay"
columns[9][5] = "sys.class.xdsl.@line0.UpstreamUASCurrentDay"
columns[10][5] = "sys.class.xdsl.@line0.DownstreamUASCurrentDay"
columns[11][5] = "sys.class.xdsl.@line0.UpstreamLOSCurrentDay"
columns[12][5] = "sys.class.xdsl.@line0.DownstreamLOSCurrentDay"
columns[13][5] = "sys.class.xdsl.@line0.UpstreamLOFCurrentDay"
columns[14][5] = "sys.class.xdsl.@line0.DownstreamLOFCurrentDay"
columns[15][5] = "sys.class.xdsl.@line0.UpstreamLOMCurrentDay"
columns[16][5] = "sys.class.xdsl.@line0.DownstreamLOMCurrentDay"

columns[1][6] = "sys.class.xdsl.@line0.UpstreamFECPreviousDay"
columns[2][6] = "sys.class.xdsl.@line0.DownstreamFECPreviousDay"
columns[3][6] = "sys.class.xdsl.@line0.UpstreamCRCPreviousDay"
columns[4][6] = "sys.class.xdsl.@line0.DownstreamCRCPreviousDay"
columns[5][6] = "sys.class.xdsl.@line0.UpstreamESPreviousDay"
columns[6][6] = "sys.class.xdsl.@line0.DownstreamESPreviousDay"
columns[7][6] = "sys.class.xdsl.@line0.UpstreamSESPreviousDay"
columns[8][6] = "sys.class.xdsl.@line0.DownstreamSESPreviousDay"
columns[9][6] = "sys.class.xdsl.@line0.UpstreamUASPreviousDay"
columns[10][6] = "sys.class.xdsl.@line0.DownstreamUASPreviousDay"
columns[11][6] = "sys.class.xdsl.@line0.UpstreamLOSPreviousDay"
columns[12][6] = "sys.class.xdsl.@line0.DownstreamLOSPreviousDay"
columns[13][6] = "sys.class.xdsl.@line0.UpstreamLOFPreviousDay"
columns[14][6] = "sys.class.xdsl.@line0.DownstreamLOFPreviousDay"
columns[15][6] = "sys.class.xdsl.@line0.UpstreamLOMPreviousDay"
columns[16][6] = "sys.class.xdsl.@line0.DownstreamLOMPreviousDay"

columns[1][7] = "sys.class.xdsl.@line0.UpstreamFECSinceSync"
columns[2][7] = "sys.class.xdsl.@line0.DownstreamFECSinceSync"
columns[3][7] = "sys.class.xdsl.@line0.UpstreamCRCSinceSync"
columns[4][7] = "sys.class.xdsl.@line0.DownstreamCRCSinceSync"
columns[5][7] = "sys.class.xdsl.@line0.UpstreamESSinceSync"
columns[6][7] = "sys.class.xdsl.@line0.DownstreamESSinceSync"
columns[7][7] = "sys.class.xdsl.@line0.UpstreamSESSinceSync"
columns[8][7] = "sys.class.xdsl.@line0.DownstreamSESSinceSync"
columns[9][7] = "sys.class.xdsl.@line0.UpstreamUASSinceSync"
columns[10][7] = "sys.class.xdsl.@line0.DownstreamUASSinceSync"
columns[11][7] = "sys.class.xdsl.@line0.UpstreamLOSSinceSync"
columns[12][7] = "sys.class.xdsl.@line0.DownstreamLOSSinceSync"
columns[13][7] = "sys.class.xdsl.@line0.UpstreamLOFSinceSync"
columns[14][7] = "sys.class.xdsl.@line0.DownstreamLOFSinceSync"
columns[15][7] = "sys.class.xdsl.@line0.UpstreamLOMSinceSync"
columns[16][7] = "sys.class.xdsl.@line0.DownstreamLOMSinceSync"

local dsl_stats={}
for i=1, 16 do
  local column = columns[i]
  for i=2, 7 do
    dsl_stats[#dsl_stats+1]= column[i]
  end
end
--Here we saved around 8 seconds by querying with required parameters.
--Because it was taking 8 seconds additionally when we were using the "sys.class.xdsl.@line0."
local result = proxy.get(unpack(dsl_stats)) or {}
if result ~=nil and #result > 0 then
  local temp = {true}
  for _,v in ipairs(result) do
    temp[v.path..v.param] = v.value
  end
  for k = 2, #columns[1] do
    for ke = 1, #columns do
      columns[ke][k] = temp [columns[ke][k]] or ""
    end
  end
end

local content ={
   showBondingStats = "sys.class.xdsl.@line0.BondingSupport",
   firmware_version="sys.class.xdsl.@line0.FirmwareVersion"
}
content_helper.getExactContent(content)
if content["showBondingStats"] == 1 then
  showBondingStats = true
  columns1[1][1] = T"Upstream FEC"
  columns1[2][1] = T"Downstream FEC"
  columns1[3][1] = T"Upstream CRC"
  columns1[4][1] = T"Downstream CRC"
  columns1[5][1] = T"Upstream ES"
  columns1[6][1] = T"Downstream ES"
  columns1[7][1] = T"Upstream SES"
  columns1[8][1] = T"Downstream SES"
  columns1[9][1] = T"Upstream UAS"
  columns1[10][1] = T"Downstream UAS"
  columns1[11][1] = T"Upstream LOS"
  columns1[12][1] = T"Downstream LOS"
  columns1[13][1] = T"Upstream LOF"
  columns1[14][1] = T"Downstream LOF"
  columns1[15][1] = T"Upstream LOM"
  columns1[16][1] = T"Downstream LOM"

  columns1[1][2] = "sys.class.xdsl.@line1.UpstreamFECTotal"
  columns1[2][2] = "sys.class.xdsl.@line1.DownstreamFECTotal"
  columns1[3][2] = "sys.class.xdsl.@line1.UpstreamCRCTotal"
  columns1[4][2] = "sys.class.xdsl.@line1.DownstreamCRCTotal"
  columns1[5][2] = "sys.class.xdsl.@line1.UpstreamESTotal"
  columns1[6][2] = "sys.class.xdsl.@line1.DownstreamESTotal"
  columns1[7][2] = "sys.class.xdsl.@line1.UpstreamSESTotal"
  columns1[8][2] = "sys.class.xdsl.@line1.DownstreamSESTotal"
  columns1[9][2] = "sys.class.xdsl.@line1.UpstreamUASTotal"
  columns1[10][2] = "sys.class.xdsl.@line1.DownstreamUASTotal"
  columns1[11][2] = "sys.class.xdsl.@line1.UpstreamLOSTotal"
  columns1[12][2] = "sys.class.xdsl.@line1.DownstreamLOSTotal"
  columns1[13][2] = "sys.class.xdsl.@line1.UpstreamLOFTotal"
  columns1[14][2] = "sys.class.xdsl.@line1.DownstreamLOFTotal"
  columns1[15][2] = "sys.class.xdsl.@line1.UpstreamLOMTotal"
  columns1[16][2] = "sys.class.xdsl.@line1.DownstreamLOMTotal"

  columns1[1][3] = "sys.class.xdsl.@line1.UpstreamFECCurrentQuarter"
  columns1[2][3] = "sys.class.xdsl.@line1.DownstreamFECCurrentQuarter"
  columns1[3][3] = "sys.class.xdsl.@line1.UpstreamCRCCurrentQuarter"
  columns1[4][3] = "sys.class.xdsl.@line1.DownstreamCRCCurrentQuarter"
  columns1[5][3] = "sys.class.xdsl.@line1.UpstreamESCurrentQuarter"
  columns1[6][3] = "sys.class.xdsl.@line1.DownstreamESCurrentQuarter"
  columns1[7][3] = "sys.class.xdsl.@line1.UpstreamSESCurrentQuarter"
  columns1[8][3] = "sys.class.xdsl.@line1.DownstreamSESCurrentQuarter"
  columns1[9][3] = "sys.class.xdsl.@line1.UpstreamUASCurrentQuarter"
  columns1[10][3] = "sys.class.xdsl.@line1.DownstreamUASCurrentQuarter"
  columns1[11][3] = "sys.class.xdsl.@line1.UpstreamLOSCurrentQuarter"
  columns1[12][3] = "sys.class.xdsl.@line1.DownstreamLOSCurrentQuarter"
  columns1[13][3] = "sys.class.xdsl.@line1.UpstreamLOFCurrentQuarter"
  columns1[14][3] = "sys.class.xdsl.@line1.DownstreamLOFCurrentQuarter"
  columns1[15][3] = "sys.class.xdsl.@line1.UpstreamLOMCurrentQuarter"
  columns1[16][3] = "sys.class.xdsl.@line1.DownstreamLOMCurrentQuarter"

  columns1[1][4] = "sys.class.xdsl.@line1.UpstreamFECPreviousQuarter"
  columns1[2][4] = "sys.class.xdsl.@line1.DownstreamFECPreviousQuarter"
  columns1[3][4] = "sys.class.xdsl.@line1.UpstreamCRCPreviousQuarter"
  columns1[4][4] = "sys.class.xdsl.@line1.DownstreamCRCPreviousQuarter"
  columns1[5][4] = "sys.class.xdsl.@line1.UpstreamESPreviousQuarter"
  columns1[6][4] = "sys.class.xdsl.@line1.DownstreamESPreviousQuarter"
  columns1[7][4] = "sys.class.xdsl.@line1.UpstreamSESPreviousQuarter"
  columns1[8][4] = "sys.class.xdsl.@line1.DownstreamSESPreviousQuarter"
  columns1[9][4] = "sys.class.xdsl.@line1.UpstreamUASPreviousQuarter"
  columns1[10][4] = "sys.class.xdsl.@line1.DownstreamUASPreviousQuarter"
  columns1[11][4] = "sys.class.xdsl.@line1.UpstreamLOSPreviousQuarter"
  columns1[12][4] = "sys.class.xdsl.@line1.DownstreamLOSPreviousQuarter"
  columns1[13][4] = "sys.class.xdsl.@line1.UpstreamLOFPreviousQuarter"
  columns1[14][4] = "sys.class.xdsl.@line1.DownstreamLOFPreviousQuarter"
  columns1[15][4] = "sys.class.xdsl.@line1.UpstreamLOMPreviousQuarter"
  columns1[16][4] = "sys.class.xdsl.@line1.DownstreamLOMPreviousQuarter"

  columns1[1][5] = "sys.class.xdsl.@line1.UpstreamFECCurrentDay"
  columns1[2][5] = "sys.class.xdsl.@line1.DownstreamFECCurrentDay"
  columns1[3][5] = "sys.class.xdsl.@line1.UpstreamCRCCurrentDay"
  columns1[4][5] = "sys.class.xdsl.@line1.DownstreamCRCCurrentDay"
  columns1[5][5] = "sys.class.xdsl.@line1.UpstreamESCurrentDay"
  columns1[6][5] = "sys.class.xdsl.@line1.DownstreamESCurrentDay"
  columns1[7][5] = "sys.class.xdsl.@line1.UpstreamSESCurrentDay"
  columns1[8][5] = "sys.class.xdsl.@line1.DownstreamSESCurrentDay"
  columns1[9][5] = "sys.class.xdsl.@line1.UpstreamUASCurrentDay"
  columns1[10][5] = "sys.class.xdsl.@line1.DownstreamUASCurrentDay"
  columns1[11][5] = "sys.class.xdsl.@line1.UpstreamLOSCurrentDay"
  columns1[12][5] = "sys.class.xdsl.@line1.DownstreamLOSCurrentDay"
  columns1[13][5] = "sys.class.xdsl.@line1.UpstreamLOFCurrentDay"
  columns1[14][5] = "sys.class.xdsl.@line1.DownstreamLOFCurrentDay"
  columns1[15][5] = "sys.class.xdsl.@line1.UpstreamLOMCurrentDay"
  columns1[16][5] = "sys.class.xdsl.@line1.DownstreamLOMCurrentDay"

  columns1[1][6] = "sys.class.xdsl.@line1.UpstreamFECPreviousDay"
  columns1[2][6] = "sys.class.xdsl.@line1.DownstreamFECPreviousDay"
  columns1[3][6] = "sys.class.xdsl.@line1.UpstreamCRCPreviousDay"
  columns1[4][6] = "sys.class.xdsl.@line1.DownstreamCRCPreviousDay"
  columns1[5][6] = "sys.class.xdsl.@line1.UpstreamESPreviousDay"
  columns1[6][6] = "sys.class.xdsl.@line1.DownstreamESPreviousDay"
  columns1[7][6] = "sys.class.xdsl.@line1.UpstreamSESPreviousDay"
  columns1[8][6] = "sys.class.xdsl.@line1.DownstreamSESPreviousDay"
  columns1[9][6] = "sys.class.xdsl.@line1.UpstreamUASPreviousDay"
  columns1[10][6] = "sys.class.xdsl.@line1.DownstreamUASPreviousDay"
  columns1[11][6] = "sys.class.xdsl.@line1.UpstreamLOSPreviousDay"
  columns1[12][6] = "sys.class.xdsl.@line1.DownstreamLOSPreviousDay"
  columns1[13][6] = "sys.class.xdsl.@line1.UpstreamLOFPreviousDay"
  columns1[14][6] = "sys.class.xdsl.@line1.DownstreamLOFPreviousDay"
  columns1[15][6] = "sys.class.xdsl.@line1.UpstreamLOMPreviousDay"
  columns1[16][6] = "sys.class.xdsl.@line1.DownstreamLOMPreviousDay"

  columns1[1][7] = "sys.class.xdsl.@line1.UpstreamFECSinceSync"
  columns1[2][7] = "sys.class.xdsl.@line1.DownstreamFECSinceSync"
  columns1[3][7] = "sys.class.xdsl.@line1.UpstreamCRCSinceSync"
  columns1[4][7] = "sys.class.xdsl.@line1.DownstreamCRCSinceSync"
  columns1[5][7] = "sys.class.xdsl.@line1.UpstreamESSinceSync"
  columns1[6][7] = "sys.class.xdsl.@line1.DownstreamESSinceSync"
  columns1[7][7] = "sys.class.xdsl.@line1.UpstreamSESSinceSync"
  columns1[8][7] = "sys.class.xdsl.@line1.DownstreamSESSinceSync"
  columns1[9][7] = "sys.class.xdsl.@line1.UpstreamUASSinceSync"
  columns1[10][7] = "sys.class.xdsl.@line1.DownstreamUASSinceSync"
  columns1[11][7] = "sys.class.xdsl.@line1.UpstreamLOSSinceSync"
  columns1[12][7] = "sys.class.xdsl.@line1.DownstreamLOSSinceSync"
  columns1[13][7] = "sys.class.xdsl.@line1.UpstreamLOFSinceSync"
  columns1[14][7] = "sys.class.xdsl.@line1.DownstreamLOFSinceSync"
  columns1[15][7] = "sys.class.xdsl.@line1.UpstreamLOMSinceSync"
  columns1[16][7] = "sys.class.xdsl.@line1.DownstreamLOMSinceSync"
  local dsl_stats1={}
  for i=1, 16 do
    local column = columns[i]
    for i=2, 7 do
      dsl_stats1[#dsl_stats+1]= column[i]
    end
  end
  local result = proxy.get(unpack(dsl_stats1)) or {}
  if result ~= nil  and #result > 0 then
    local temp1 = {}
      for _,v in ipairs(result1) do
      temp1[v.path..v.param] = v.value
    end
    for k = 2, #columns1[1] do
      for ke = 1, #columns1 do
        columns1[ke][k] = temp1 [columns1[ke][k]] or ""
      end
    end
  end
  xdsl_BitLoading1 = temp1[xdsl_BitLoading1]
else
  showBondingStats = false
end

-- Datarows Names
local datarows ={}
for i=1, 7 do
    datarows[i]={}
end

datarows[1]["header"] = T"Parameters"
datarows[2]["header"] = T"Total"
datarows[3]["header"] = T"Current Quarter"
datarows[4]["header"] = T"Previous Quarter"
datarows[5]["header"] = T"Current Day"
datarows[6]["header"] = T"Previous Day"
datarows[7]["header"] = T"Since Sync"
  ngx.print('\
\
');  ngx.print(ui_helper.createHeader(T"Diagnostics DSL", true, true))   ngx.print('\
\
<div class="modal-body update">\
');  
    local lp = require("web.lp")
    lp.setpath("/www/snippets/")
    lp.include("tabs-diagnostics.lp")
  ngx.print('\
\
    ');  
        -- dummy form so that refresh button knows which page to reload, keep it
      ngx.print('\
    <form class="form-horizontal" method="post" action="modals/diagnostics-xdsl-modal.lp">\
    </form>\
\
    <fieldset id="diagnostics-xdsl-tab">\
      <legend>');  ngx.print( T"DSL stats" ); ngx.print('</legend>\
      ');  
        local options = { tableid = "xdslstats", canEdit = false, editing = false, minEntries =7 , maxEntries =17, createMsg = "Create new", canAdd = false, canDelete = false, newList = true, errmsg = nil}
        local options1 = { tableid = "xdslstats1", canEdit = false, editing = false, minEntries =7 , maxEntries =17, createMsg = "Create new", canAdd = false, canDelete = false, newList = true, errmsg = nil}
        -- table that shows the Statistics data
        ngx.print(ui_helper.createTable(datarows, columns, options))
        if content["showBondingStats"] == "1" then
          ngx.print(format('<legend>%s</legend>', T"DSL Bit Loading (Line 1)"))
          ngx.print(ui_helper.createTable(datarows, columns1, options1))
        end
        ngx.print('\
    </fieldset>\
    <div id="xdsl_advanced_data" class="advanced hide"><img src="/img/loading.gif"/></div>\
    <fieldset>\
      <legend>');  ngx.print( T"DSL Bit Loading" ); ngx.print('</legend>\
      <div id="dsl_bit_chart" style="max-width:880px;overflow-x:auto"><img src="/img/loading.gif"/></div>\
    </fieldset>\
    <font color="white">\
      ');  
        ngx.print(T(content["firmware_version"]))
        ngx.print('\
    </font>\
</div>\
\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
<script>\
$.get("/modals/diagnostics-xdsl-modal.lp?action=GET_BITS&show_line_one=');  ngx.print(content["showBondingStats"]); ngx.print('", function (data){\
   $(\'#dsl_bit_chart\').replaceWith(data);\
});\
$.get("/modals/diagnostics-xdsl-modal.lp?action=GET_ADVANCED_DATA", function (data){\
    $(\'#xdsl_advanced_data\').replaceWith(data);\
    $(\'.modal-action-advanced\').each(function(){\
        var obj = $(this);\
        if(obj.html() != null && obj.html().indexOf("hide") > -1 &&\
          obj.attr("style") != undefined && obj.attr("style").indexOf("inline") > -1){\
            $("#diagnostics-xdsl-framing").removeClass("hide");\
            $("#diagnostics-xdsl-ginp").removeClass("hide");\
            $("#diagnostics-xdsl-vectoring").removeClass("hide");\
        }\
    });\
});\
</script>\
'); 