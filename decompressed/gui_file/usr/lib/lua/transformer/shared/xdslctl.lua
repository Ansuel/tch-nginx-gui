-- helper functions to wrap xdslctl utility from broadcom
local cmdhelper = require("transformer.shared.cmdhelper")
local uci_helper = require("transformer.mapper.ucihelper")
local luabcm = require("luabcm")

local tonumber, tostring, os, setmetatable, string, lower = tonumber, tostring, os, setmetatable, string, lower

local M = {}
local encodeBooleanMap = {
  ["off"]      = 0,
  ["on"]       = 1,
  ["enabled"]  = 1,
  ["disabled"] = 0
}

-- if encodeBooleanMap table is accessed with known index respective value is returned
-- else if table is accessed with unknown/nil index/key, return ""
local function decodeBooleanConfig(str)
  str = str and string.lower(str)
  return encodeBooleanMap[str] or ""
end

local function adjustScale(nr)
  return nr and tostring( nr / 10 ) or "0"
end

-- generic values table for cmdhelper.parseCmd
local xdslInfo = {}
-- the adslMib to be loaded to data model for the current lineid
local adslMib = {}
-- cache of adslMib for line0 and line1
local adslMibCache = {
  [0] = {},
  [1] = {}
}
local tmp
-- last update time for line0 and line1
local lastUpdateTime = {
  [0] = 0,
  [1] = 0
}

local xdslctlinfo0 = { command = "xdslctl info --show", lookup = {
  status = { pat = "^Status:%s+(%S+)"},
  tpstc  = { pat= "^TPS%-TC:%s+(.*)$"},
  linit  = { pat = "^Last initialization procedure status:%s+(.*)$"},
}}

local xdslctlinfo1 = { command = "xdslctl1 info --show", lookup={
  status = { pat = "^Status:%s+(%S+)"},
  tpstc = { pat = "^TPS%-TC:%s+(.*)$"},
}}

local xdslctlinfo = { line0 = xdslctlinfo0, line1 = xdslctlinfo1 }

-- Setup a default value to be line0
local function setDefault(t, d)
  local mt = {__index = function () return d end}
  setmetatable(t, mt)
end
setDefault(xdslctlinfo, xdslctlinfo0)

local function valueFromCmd(cmdlookup, key, subkey, defaultvalue)
  cmdhelper.parseCmd(cmdlookup, {key}, xdslInfo)
  local val = xdslInfo[key]
  if val and val[subkey] then
    return val[subkey]
  elseif val then
    return val
  end
  return defaultvalue
end

local function addEmptyAdslMib(mibparam1, value1, mibparam2, value2)
  adslMib[mibparam1] = value1
  if mibparam2 then
    adslMib[mibparam2] = value2
  end
end

local function createTableWithEmptyValues()
  adslMib = {}
  addEmptyAdslMib( "GDMT", 0 )
  addEmptyAdslMib( "GLITE", 0 )
  addEmptyAdslMib( "T1413", 0 )
  addEmptyAdslMib( "ADSL2", 0 )
  addEmptyAdslMib( "ANNEXL", 0 )
  addEmptyAdslMib( "ADSL2P", 0 )
  addEmptyAdslMib( "ANNEXM", 0 )
  addEmptyAdslMib( "VDSL2", 0 )
  addEmptyAdslMib( "GFAST", 0 )
  addEmptyAdslMib( "LinePair", 1 )
  addEmptyAdslMib( "Bitswap", 0 )
  addEmptyAdslMib( "SRA", 0 )
  addEmptyAdslMib( "Trellis", 0 )
  addEmptyAdslMib( "SESDrop", 0 )
  addEmptyAdslMib( "CoMinMgn", 0 )
  addEmptyAdslMib( "24k", 0 )
  addEmptyAdslMib( "PhyReXmtUs", 0 )
  addEmptyAdslMib( "PhyReXmtDs", 0 )
  addEmptyAdslMib( "TpsTc", nil )
  addEmptyAdslMib( "MonitorTone", 0 )
  addEmptyAdslMib( "DynamicD", 0 )
  addEmptyAdslMib( "DynamicF", 0 )
  addEmptyAdslMib( "V43", 0 )
  addEmptyAdslMib( "SOS", 0 )
  addEmptyAdslMib( "TrainingMargin", 0 )
  addEmptyAdslMib( "GINPUs", 0 )
  addEmptyAdslMib( "GINPDs", 0 )
  addEmptyAdslMib( "IKNS", 0 )
  addEmptyAdslMib( "TrainingStatus", "Disabled")
  addEmptyAdslMib( "Mode", "Unknown" )
  addEmptyAdslMib( "LastRetrainReason", "")
  addEmptyAdslMib( "LastInitializationProcedureStatus", 0)
  addEmptyAdslMib( "DownstreamMaxBitRate", 0, "UpstreamMaxBitRate", 0)
  addEmptyAdslMib( "DownstreamCurrRate", 0, "UpstreamCurrRate", 0)
  addEmptyAdslMib( "PowerManagementState", 0)
  addEmptyAdslMib( "CurrentProfile", 0)
  addEmptyAdslMib( "TpsTcBcm" )
  addEmptyAdslMib( "LineStatus", "Disabled")
  addEmptyAdslMib( "TrainingStatus", "Disabled")
  addEmptyAdslMib( "TRELLISds", 0, "TRELLISus", 0)
  addEmptyAdslMib( "DownstreamSNR", 0, "UpstreamSNR", 0)
  addEmptyAdslMib( "DownstreamAttenuation", 0, "UpstreamAttenuation", 0)
  addEmptyAdslMib( "DownstreamPower", 0,"UpstreamPower", 0)
  addEmptyAdslMib( "DownstreamFramingMSGc", 0,"UpstreamFramingMSGc", 0 )
  addEmptyAdslMib( "DownstreamFramingB", 0, "UpstreamFramingB", 0)
  addEmptyAdslMib( "DownstreamFramingM", 0, "UpstreamFramingM", 0)
  addEmptyAdslMib( "DownstreamFramingT", 0, "UpstreamFramingT", 0)
  addEmptyAdslMib( "DownstreamFramingR", 0, "UpstreamFramingR", 0)
  addEmptyAdslMib( "DownstreamFramingS", 0, "UpstreamFramingS", 0)
  addEmptyAdslMib( "DownstreamFramingL", 0, "UpstreamFramingL", 0)
  addEmptyAdslMib( "DownstreamInterleaveDepth", 0, "UpstreamInterleaveDepth", 0)
  addEmptyAdslMib( "DownstreamFramingI", 0, "UpstreamFramingI", 0)
  addEmptyAdslMib( "DownstreamFramingN", 0, "UpstreamFramingN", 0)
  addEmptyAdslMib( "DownstreamFramingQ", 0, "UpstreamFramingQ", 0)
  addEmptyAdslMib( "DownstreamFramingV", 0, "UpstreamFramingV", 0)
  addEmptyAdslMib( "DownstreamFramingK", 0, "UpstreamFramingK", 0)
  addEmptyAdslMib( "OHFDs", 0, "OHFUs", 0)
  addEmptyAdslMib( "OHFErrDs", 0, "OHFErrUs", 0)
  addEmptyAdslMib( "SFDs", 0, "SFUs", 0)
  addEmptyAdslMib( "SFErrDs", 0, "SFErrUs", 0)
  addEmptyAdslMib( "RSDs", 0, "RSUs", 0)
  addEmptyAdslMib( "RSCorrDs", 0, "RSCorrUs", 0)
  addEmptyAdslMib( "RSUnCorrDs", 0, "RSUnCorrUs", 0)
  addEmptyAdslMib( "ShowtimeXTURHECErrors", 0, "ShowtimeXTUCHECErrors", 0)
  addEmptyAdslMib( "OCDDs", 0, "OCDUs", 0)
  addEmptyAdslMib( "LCDDs", 0, "LCDUs", 0)
  addEmptyAdslMib( "BytesReceived", 0, "BytesSent", 0)
  addEmptyAdslMib( "PacketsReceived", 0, "PacketsSent", 0)
  addEmptyAdslMib( "DiscardPacektsReceived", 0, "DiscardPacektsSent", 0)
  addEmptyAdslMib( "ErrorsReceived", 0, "ErrorsSent", 0)
  addEmptyAdslMib( "ShowtimeErroredSecsDs", 0, "ShowtimeErroredSecsUs", 0)
  addEmptyAdslMib( "ShowtimeSeverelyErroredSecsDs", 0, "ShowtimeSeverelyErroredSecsUs", 0)
  addEmptyAdslMib( "ShowtimeUnavailableSecsDs", 0, "ShowtimeUnavailableSecsUs", 0)
  addEmptyAdslMib( "ShowtimeAvailableSecs", 0)
  addEmptyAdslMib( "INPDs", 0, "INPUs", 0)
  addEmptyAdslMib( "INPReinDs", 0, "INPReinUs", 0)
  addEmptyAdslMib( "DownstreamDelay", 0, "UpstreamDelay", 0)
  addEmptyAdslMib( "PERDs", 0, "PERUs", 0)
  addEmptyAdslMib( "ORDs", 0, "ORUs", 0)
  addEmptyAdslMib( "AGRDs", 0, "AGRUs", 0)
  addEmptyAdslMib( "BitswapDs", 0, "BitswapUs", 0)
  addEmptyAdslMib( "DownstreamNoiseMargin", 0, "UpstreamNoiseMargin", 0)
  addEmptyAdslMib( "TotalXTURFECErrors", 0, "TotalXTUCFECErrors", 0)
  addEmptyAdslMib( "TotalXTURCRCErrors", 0, "TotalXTUCCRCErrors", 0)
  addEmptyAdslMib( "TotalXTURHECErrors", 0, "TotalXTUCHECErrors", 0)
  addEmptyAdslMib( "TotalErroredSecsDs", 0, "TotalErroredSecsUs", 0)
  addEmptyAdslMib( "TotalSeverelyErroredSecsDs", 0, "TotalSeverelyErroredSecsUs", 0)
  addEmptyAdslMib( "TotalUnavailableSecsDs", 0, "TotalUnavailableSecsUs", 0)
  addEmptyAdslMib( "TotalLossOfSignalSecsDs", 0, "TotalLossOfSignalSecsUs", 0)
  addEmptyAdslMib( "TotalLossOfFramingSecsDs", 0, "TotalLossOfFramingSecsUs", 0)
  addEmptyAdslMib( "TotalLossOfMarginSecsDs", 0, "TotalLossOfMarginSecsUs", 0)
  addEmptyAdslMib( "TotalRetrainCount", "0")
  addEmptyAdslMib( "TotalTime", 0)
  addEmptyAdslMib( "TotalStart", 0)
  addEmptyAdslMib( "QuarterHourXTURFECErrors", 0, "QuarterHourXTUCFECErrors", 0)
  addEmptyAdslMib( "QuarterHourXTURCRCErrors", 0, "QuarterHourXTUCCRCErrors", 0)
  addEmptyAdslMib( "QuarterHourXTURHECErrors", 0, "QuarterHourXTUCHECErrors", 0)
  addEmptyAdslMib( "QuarterHourErroredSecsDs", 0, "QuarterHourErroredSecsUs", 0)
  addEmptyAdslMib( "QuarterHourSeverelyErroredSecsDs", 0, "QuarterHourSeverelyErroredSecsUs", 0)
  addEmptyAdslMib( "QuarterHourUnavailableSecsDs", 0, "QuarterHourUnavailableSecsUs", 0)
  addEmptyAdslMib( "QuarterHourLossOfSignalSecsDs", 0, "QuarterHourLossOfSignalSecsUs", 0)
  addEmptyAdslMib( "QuarterHourLossOfFramingSecsDs", 0, "QuarterHourLossOfFramingSecsUs", 0)
  addEmptyAdslMib( "QuarterHourLossOfMarginSecsDs", 0, "QuarterHourLossOfMarginSecsUs", 0)
  addEmptyAdslMib( "QuarterHourRetrainCount", "0")
  addEmptyAdslMib( "QuarterHourTime", 0)
  addEmptyAdslMib( "QuarterHourStart", 0)
  addEmptyAdslMib( "PreviousQuarterHourXTURFECErrors", 0, "PreviousQuarterHourXTUCFECErrors", 0)
  addEmptyAdslMib( "PreviousQuarterHourXTURCRCErrors", 0, "PreviousQuarterHourXTUCCRCErrors", 0)
  addEmptyAdslMib( "PreviousQuarterHourXTURHECErrors", 0, "PreviousQuarterHourXTUCHECErrors", 0)
  addEmptyAdslMib( "PreviousQuarterHourErroredSecsDs", 0, "PreviousQuarterHourErroredSecsUs", 0)
  addEmptyAdslMib( "PreviousQuarterHourSeverelyErroredSecsDs", 0, "PreviousQuarterHourSeverelyErroredSecsUs", 0)
  addEmptyAdslMib( "PreviousQuarterHourUnavailableSecsDs", 0, "PreviousQuarterHourUnavailableSecsUs", 0)
  addEmptyAdslMib( "PreviousQuarterHourLossOfSignalSecsDs", 0, "PreviousQuarterHourLossOfSignalSecsUs", 0)
  addEmptyAdslMib( "PreviousQuarterHourLossOfFramingSecsDs", 0, "PreviousQuarterHourLossOfFramingSecsUs", 0)
  addEmptyAdslMib( "PreviousQuarterHourLossOfMarginSecsDs", 0, "PreviousQuarterHourLossOfMarginSecsUs", 0)
  addEmptyAdslMib( "PreviousQuarterHourRetrainCount", "0")
  addEmptyAdslMib( "PreviousQuarterHourTime", 0)
  addEmptyAdslMib( "CurrentDayXTURFECErrors", 0, "CurrentDayXTUCFECErrors", 0)
  addEmptyAdslMib( "CurrentDayXTURCRCErrors", 0, "CurrentDayXTUCCRCErrors", 0)
  addEmptyAdslMib( "CurrentDayXTURHECErrors", 0, "CurrentDayXTUCHECErrors", 0)
  addEmptyAdslMib( "CurrentDayErroredSecsDs", 0, "CurrentDayErroredSecsUs", 0)
  addEmptyAdslMib( "CurrentDaySeverelyErroredSecsDs", 0, "CurrentDaySeverelyErroredSecsUs", 0)
  addEmptyAdslMib( "CurrentDayUnavailableSecsDs", 0, "CurrentDayUnavailableSecsUs", 0)
  addEmptyAdslMib( "CurrentDayLossOfSignalSecsDs", 0, "CurrentDayLossOfSignalSecsUs", 0)
  addEmptyAdslMib( "CurrentDayLossOfFramingSecsDs", 0, "CurrentDayLossOfFramingSecsUs", 0)
  addEmptyAdslMib( "CurrentDayLossOfMarginSecsDs", 0, "CurrentDayLossOfMarginSecsUs", 0)
  addEmptyAdslMib( "CurrentDayRetrainCount", "0")
  addEmptyAdslMib( "CurrentDayTime", 0)
  addEmptyAdslMib( "CurrentDayStart", 0)
  addEmptyAdslMib( "PreviousDayXTURFECErrors", 0, "PreviousDayXTUCFECErrors", 0)
  addEmptyAdslMib( "PreviousDayXTURCRCErrors", 0, "PreviousDayXTUCCRCErrors", 0)
  addEmptyAdslMib( "PreviousDayXTURHECErrors", 0, "PreviousDayXTUCHECErrors", 0)
  addEmptyAdslMib( "PreviousDayErroredSecsDs", 0, "PreviousDayErroredSecsUs", 0)
  addEmptyAdslMib( "PreviousDaySeverelyErroredSecsDs", 0, "PreviousDaySeverelyErroredSecsUs", 0)
  addEmptyAdslMib( "PreviousDayUnavailableSecsDs", 0, "PreviousDayUnavailableSecsUs", 0)
  addEmptyAdslMib( "PreviousDayLossOfSignalSecsDs", 0, "PreviousDayLossOfSignalSecsUs", 0)
  addEmptyAdslMib( "PreviousDayLossOfFramingSecsDs", 0, "PreviousDayLossOfFramingSecsUs", 0)
  addEmptyAdslMib( "PreviousDayLossOfMarginSecsDs", 0, "PreviousDayLossOfMarginSecsUs", 0)
  addEmptyAdslMib( "PreviousDayRetrainCount", "0")
  addEmptyAdslMib( "PreviousDayTime", 0)
  addEmptyAdslMib( "ShowtimeXTURFECErrors", 0, "ShowtimeXTUCFECErrors", 0)
  addEmptyAdslMib( "ShowtimeXTURCRCErrors", 0, "ShowtimeXTUCCRCErrors", 0)
  addEmptyAdslMib( "ShowtimeXTURHECErrors", 0, "ShowtimeXTUCHECErrors", 0)
  addEmptyAdslMib( "ShowtimeErroredSecsDs", 0, "ShowtimeErroredSecsUs", 0)
  addEmptyAdslMib( "LastShowtimeUnavailableSecsDs", 0, "LastShowtimeUnavailableSecsUs", 0)
  addEmptyAdslMib( "LastShowtimeLossOfSignalSecsDs", 0, "LastShowtimeLossOfSignalSecsUs", 0)
  addEmptyAdslMib( "LastShowtimeLossOfFramingSecsDs", 0, "LastShowtimeLossOfFramingSecsUs", 0)
  addEmptyAdslMib( "LastShowtimeLossOfMarginSecsDs", 0, "LastShowtimeLossOfMarginSecsUs", 0)
  addEmptyAdslMib( "LastShowtimeRetrainCount", "0")
  addEmptyAdslMib( "ShowtimeSeverelyErroredSecsDs", 0, "ShowtimeSeverelyErroredSecsUs", 0)
  addEmptyAdslMib( "ShowtimeUnavailableSecsDs", 0, "ShowtimeUnavailableSecsUs", 0)
  addEmptyAdslMib( "ShowtimeLossOfSignalSecsDs", 0, "ShowtimeLossOfSignalSecsUs", 0)
  addEmptyAdslMib( "ShowtimeLossOfFramingSecsDs", 0, "ShowtimeLossOfFramingSecsUs", 0)
  addEmptyAdslMib( "ShowtimeLossOfMarginSecsDs", 0, "ShowtimeLossOfMarginSecsUs", 0)
  addEmptyAdslMib( "ShowtimeRetrainCount", "0")
  addEmptyAdslMib( "ShowtimeTime", 0)
  addEmptyAdslMib( "ShowtimeStart", 0)
  addEmptyAdslMib( "LastShowtimeXTURFECErrors", 0, "LastShowtimeXTUCFECErrors", 0)
  addEmptyAdslMib( "LastShowtimeXTURCRCErrors", 0, "LastShowtimeXTUCCRCErrors", 0)
  addEmptyAdslMib( "LastShowtimeXTURHECErrors", 0, "LastShowtimeXTURHECErrors", 0)
  addEmptyAdslMib( "LastShowtimeErroredSecsDs", 0, "LastShowtimeErroredSecsUs", 0)
  addEmptyAdslMib( "LastShowtimeSeverelyErroredSecsDs", 0, "LastShowtimeSeverelyErroredSecsUs", 0)
  addEmptyAdslMib( "LastShowtimeTime", 0)
  addEmptyAdslMib( "LastShowtimeStart", 0)
  addEmptyAdslMib( "BitLoading", "0")
  addEmptyAdslMib( "Qds", 0)
  addEmptyAdslMib( "Qus", 0)
  addEmptyAdslMib( "Vds", 0)
  addEmptyAdslMib( "Vus", 0)
  addEmptyAdslMib( "RxQueueds", 0)
  addEmptyAdslMib( "RxQueueus", 0)
  addEmptyAdslMib( "TxQueueds", 0)
  addEmptyAdslMib( "TxQueueus", 0)
  addEmptyAdslMib( "RTxModeds", 0)
  addEmptyAdslMib( "RTxModeus", 0)
  addEmptyAdslMib( "LookBackds", 0)
  addEmptyAdslMib( "LookBackus", 0)
  addEmptyAdslMib( "RRCBitsds", 0)
  addEmptyAdslMib( "RRCBitsus", 0)
  addEmptyAdslMib( "RTxTxds", 0)
  addEmptyAdslMib( "RTxTxus", 0)
  addEmptyAdslMib( "RTxCds", 0)
  addEmptyAdslMib( "RTxCus", 0)
  addEmptyAdslMib( "RTxUCds", 0)
  addEmptyAdslMib( "RTxUCus", 0)
  addEmptyAdslMib( "LEFTRSds", 0)
  addEmptyAdslMib( "LEFTRSus", 0)
  addEmptyAdslMib( "MinEFTRds", 0)
  addEmptyAdslMib( "MinEFTRus", 0)
  addEmptyAdslMib( "ErrFreeBitsds", 0)
  addEmptyAdslMib( "ErrFreeBitsus", 0)
  addEmptyAdslMib( "GINPStatus", 0)
  addEmptyAdslMib( "DirectionMode", 0)
  addEmptyAdslMib( "RxBitSwapMode", 0)
  addEmptyAdslMib( "DisableVNMode", 0)
  addEmptyAdslMib( "VceAddress", "")
  addEmptyAdslMib( "CntESPktSend", 0)
  addEmptyAdslMib( "CntESPktDrop", 0)
  addEmptyAdslMib( "CntESStatSend", 0)
  addEmptyAdslMib( "CntESStatDrop", 0)
  addEmptyAdslMib( "FirmwareVersion", " ")
  addEmptyAdslMib( "ACTINP", 0)
  addEmptyAdslMib( "ACTSNRMODEds", 0)
  addEmptyAdslMib( "ACTSNRMODEus", 0)
  addEmptyAdslMib( "ACTUALCE", 0)
  addEmptyAdslMib( "ActualInterleavingDelay", 0)
  addEmptyAdslMib( "AllowedProfiles", " ")
  addEmptyAdslMib( "HLOGGds", 0, "HLOGGus", 0)
  addEmptyAdslMib( "HLOGMTds", 0, "HLOGMTus", 0)
  addEmptyAdslMib( "HLOGpsds", " ", "HLOGpsus", " ") 
  addEmptyAdslMib( "INMCCds", 0)
  addEmptyAdslMib( "INMIATOds", 0)
  addEmptyAdslMib( "INMIATSds", 0)
  addEmptyAdslMib( "INMINPEQMODEds", 0)
  addEmptyAdslMib( "INPREPORT", 0)
  addEmptyAdslMib( "INTLVBLOCK", 0)
  addEmptyAdslMib( "INTLVDEPTH", 0)
  addEmptyAdslMib( "LATNds", " ")
  addEmptyAdslMib( "LATNus", " ")
  addEmptyAdslMib( "LIMITMASK", 0)
  addEmptyAdslMib( "LPATH", 0)
  addEmptyAdslMib( "LSYMB", 0)
  addEmptyAdslMib( "LastStateTransmittedDownstream", 0)
  addEmptyAdslMib( "LastStateTransmittedUpstream", 0)
  addEmptyAdslMib( "LineEncoding", " ")
  addEmptyAdslMib( "LinkEncapsulationSupported", " ")
  addEmptyAdslMib( "LinkEncapsulationRequested", " ")
  addEmptyAdslMib( "LinkEncapsulationUsed", " ")
  addEmptyAdslMib( "LinkStatus", " ")
  addEmptyAdslMib( "MREFPSDds", " ", "MREFPSDus", " ")
  addEmptyAdslMib( "NFEC", 0)
  addEmptyAdslMib( "RFEC", 0)
  addEmptyAdslMib( "QLNMTds", 0, "QLNMTus", 0)
  addEmptyAdslMib( "QLNpsds", " ", "QLNpsus", " ")
  addEmptyAdslMib( "SATNds", " ", "SATNus", " ")
  addEmptyAdslMib( "SNRGds", 0, "SNRGus", 0)
  addEmptyAdslMib( "SNRMTds", 0, "SNRMTus", 0)
  addEmptyAdslMib( "SNRMpbds", " ", "SNRMpbus", " ")
  addEmptyAdslMib( "SNRpsds", " ", "SNRpsus", " ")
  addEmptyAdslMib( "StandardUsed", " ")
  addEmptyAdslMib( "StandardsSupported", " ")
  addEmptyAdslMib( "SuccessFailureCause", 0)
  addEmptyAdslMib( "UPBOKLE", 0)
  addEmptyAdslMib( "UPBOKLER", 0)
  addEmptyAdslMib( "US0MASK", 0)
  addEmptyAdslMib( "VirtualNoisePSDds", " ", "VirtualNoisePSDus", " ")
  addEmptyAdslMib( "XTUCANSIRev", 0)
  addEmptyAdslMib( "XTUCANSIStd", 0)
  addEmptyAdslMib( "XTUCCountry", " ")
  addEmptyAdslMib( "XTUCVendor", " ")
  addEmptyAdslMib( "XTURANSIRev", 0)
  addEmptyAdslMib( "XTURANSIStd", 0)
  addEmptyAdslMib( "XTURCountry", " ")
  addEmptyAdslMib( "XTURVendor", " ")
  addEmptyAdslMib( "ACTATPds", 0, "ACTATPus", 0)
  addEmptyAdslMib( "ACTPSDds", 0, "ACTPSDus", 0)
  addEmptyAdslMib( "BITSpsds", " ", "BITSpsus", " ")
  addEmptyAdslMib( "HLINpsds", " ", "HLINpsus", " ")
 -- g.fast parameters
  addEmptyAdslMib( "TotalBSWStartedDs", 0 )
  addEmptyAdslMib( "TotalBSWStartedUs", 0 )
  addEmptyAdslMib( "TotalBSWCompletedDs", 0 )
  addEmptyAdslMib( "TotalBSWCompletedUs", 0 )
  addEmptyAdslMib( "TotalSRAStartedDs", 0 )
  addEmptyAdslMib( "TotalSRAStartedUs", 0 )
  addEmptyAdslMib( "TotalSRACompletedDs", 0 )
  addEmptyAdslMib( "TotalSRACompletedUs", 0 )
  addEmptyAdslMib( "TotalFRAStartedDs", 0 )
  addEmptyAdslMib( "TotalFRAStartedUs", 0 )
  addEmptyAdslMib( "TotalFRACompletedDs", 0 )
  addEmptyAdslMib( "TotalFRACompletedUs", 0 )
  addEmptyAdslMib( "TotalRPAStartedDs", 0 )
  addEmptyAdslMib( "TotalRPAStartedUs", 0 )
  addEmptyAdslMib( "TotalRPACompletedDs", 0 )
  addEmptyAdslMib( "TotalRPACompletedUs", 0 )
  addEmptyAdslMib( "TotalTIGAStartedDs", 0 )
  addEmptyAdslMib( "TotalTIGAStartedUs", 0 )
  addEmptyAdslMib( "TotalTIGACompletedDs", 0 )
  addEmptyAdslMib( "TotalTIGACompletedUs", 0 )
  addEmptyAdslMib( "TotalRTXUC", 0 )
  addEmptyAdslMib( "TotalRTXTX", 0 )
  addEmptyAdslMib( "ShowtimeBSWStartedDs", 0 )
  addEmptyAdslMib( "ShowtimeBSWStartedUs", 0 )
  addEmptyAdslMib( "ShowtimeBSWCompletedDs", 0 )
  addEmptyAdslMib( "ShowtimeBSWCompletedUs", 0 )
  addEmptyAdslMib( "ShowtimeSRAStartedDs", 0 )
  addEmptyAdslMib( "ShowtimeSRAStartedUs", 0 )
  addEmptyAdslMib( "ShowtimeSRACompletedDs", 0 )
  addEmptyAdslMib( "ShowtimeSRACompletedUs", 0 )
  addEmptyAdslMib( "ShowtimeFRAStartedDs", 0 )
  addEmptyAdslMib( "ShowtimeFRAStartedUs", 0 )
  addEmptyAdslMib( "ShowtimeFRACompletedDs", 0 )
  addEmptyAdslMib( "ShowtimeFRACompletedUs", 0 )
  addEmptyAdslMib( "ShowtimeRPAStartedDs", 0 )
  addEmptyAdslMib( "ShowtimeRPAStartedUs", 0 )
  addEmptyAdslMib( "ShowtimeRPACompletedDs", 0 )
  addEmptyAdslMib( "ShowtimeRPACompletedUs", 0 )
  addEmptyAdslMib( "ShowtimeTIGAStartedDs", 0 )
  addEmptyAdslMib( "ShowtimeTIGAStartedUs", 0 )
  addEmptyAdslMib( "ShowtimeTIGACompletedDs", 0 )
  addEmptyAdslMib( "ShowtimeTIGACompletedUs", 0 )
  addEmptyAdslMib( "ShowtimeRTXUC", 0 )
  addEmptyAdslMib( "ShowtimeRTXTX", 0 )
  addEmptyAdslMib( "LastShowtimeBSWStartedDs", 0 )
  addEmptyAdslMib( "LastShowtimeBSWStartedUs", 0 )
  addEmptyAdslMib( "LastShowtimeBSWCompletedDs", 0 )
  addEmptyAdslMib( "LastShowtimeBSWCompletedUs", 0 )
  addEmptyAdslMib( "LastShowtimeSRAStartedDs", 0 )
  addEmptyAdslMib( "LastShowtimeSRAStartedUs", 0 )
  addEmptyAdslMib( "LastShowtimeSRACompletedDs", 0 )
  addEmptyAdslMib( "LastShowtimeSRACOmpletedUs", 0 )
  addEmptyAdslMib( "LastShowtimeFRAStartedDs", 0 )
  addEmptyAdslMib( "LastShowtimeFRAStartedUs", 0 )
  addEmptyAdslMib( "LastShowtimeFRACompletedDs", 0 )
  addEmptyAdslMib( "LastShowtimeFRACompletedUs", 0 )
  addEmptyAdslMib( "LastShowtimeRPAStartedDs", 0 )
  addEmptyAdslMib( "LastShowtimeRPAStartedUs", 0 )
  addEmptyAdslMib( "LastShowtimeRPACompletedDs", 0 )
  addEmptyAdslMib( "LastShowtimeRPACompletedUs", 0 )
  addEmptyAdslMib( "LastShowtimeTIGAStartedDs", 0 )
  addEmptyAdslMib( "LastShowtimeTIGAStartedUs", 0 )
  addEmptyAdslMib( "LastShowtimeTIGACompletedDs", 0 )
  addEmptyAdslMib( "LastShowtimeTIGACompletedUs", 0 )
  addEmptyAdslMib( "LastShowtimeRTXUC", 0 )
  addEmptyAdslMib( "LastShowtimeRTXTX", 0 )
  addEmptyAdslMib( "CurrentDayBSWStartedDs", 0 )
  addEmptyAdslMib( "CurrentDayBSWStartedUs", 0 )
  addEmptyAdslMib( "CurrentDayBSWCompletedDs", 0 )
  addEmptyAdslMib( "CurrentDayBSWCompletedUs", 0 )
  addEmptyAdslMib( "CurrentDaySRAStartedDs", 0 )
  addEmptyAdslMib( "CurrentDaySRAStartedUs", 0 )
  addEmptyAdslMib( "CurrentDaySRACompletedDs", 0 )
  addEmptyAdslMib( "CurrentDaySRACompletedUs", 0 )
  addEmptyAdslMib( "CurrentDayFRAStartedDs", 0 )
  addEmptyAdslMib( "CurrentDayFRAStartedUs", 0 )
  addEmptyAdslMib( "CurrentDayFRACompletedDs", 0 )
  addEmptyAdslMib( "CurrentDayFRACompletedUs", 0 )
  addEmptyAdslMib( "CurrentDayRPAStartedDs", 0 )
  addEmptyAdslMib( "CurrentDayRPAStartedUs", 0 )
  addEmptyAdslMib( "CurrentDayRPACompletedDs", 0 )
  addEmptyAdslMib( "CurrentDayRPACompletedUs", 0 )
  addEmptyAdslMib( "CurrentDayTIGAStartedDs", 0 )
  addEmptyAdslMib( "CurrentDayTIGAStartedUs", 0 )
  addEmptyAdslMib( "CurrentDayTIGACompletedDs", 0 )
  addEmptyAdslMib( "CurrentDayTIGACompletedUs", 0 )
  addEmptyAdslMib( "CurrentDayRTXUC", 0 )
  addEmptyAdslMib( "CurrentDayRTXTX", 0 )
  addEmptyAdslMib( "QuarterHourBSWStartedDs", 0 )
  addEmptyAdslMib( "QuarterHourBSWStartedUs", 0 )
  addEmptyAdslMib( "QuarterHourBSWCompletedDs", 0 )
  addEmptyAdslMib( "QuarterHourBSWCompletedUs", 0 )
  addEmptyAdslMib( "QuarterHourSRAStartedDs", 0 )
  addEmptyAdslMib( "QuarterHourSRAStartedUs", 0 )
  addEmptyAdslMib( "QuarterHourSRACompletedDs", 0 )
  addEmptyAdslMib( "QuarterHourSRACompletedUs", 0 )
  addEmptyAdslMib( "QuarterHourFRAStartedDs", 0 )
  addEmptyAdslMib( "QuarterHourFRAStartedUs", 0 )
  addEmptyAdslMib( "QuarterHourFRACompletedDs", 0 )
  addEmptyAdslMib( "QuarterHourFRACompletedUs", 0 )
  addEmptyAdslMib( "QuarterHourRPAStartedDs", 0 )
  addEmptyAdslMib( "QuarterHourRPAStartedUs", 0 )
  addEmptyAdslMib( "QuarterHourRPACompletedDs", 0 )
  addEmptyAdslMib( "QuarterHourRPACompletedUs", 0 )
  addEmptyAdslMib( "QuarterHourTIGAStartedDs", 0 )
  addEmptyAdslMib( "QuarterHourTIGAStartedUs", 0 )
  addEmptyAdslMib( "QuarterHourTIGACompletedDs", 0 )
  addEmptyAdslMib( "QuarterHourTIGACompletedUs", 0 )
  addEmptyAdslMib( "QuarterHourRTXUC", 0 )
  addEmptyAdslMib( "QuarterHourRTXTX", 0 )
  addEmptyAdslMib( "EOCBytesSent", 0 )
  addEmptyAdslMib( "EOCBytesReceived", 0 )
  addEmptyAdslMib( "EOCPacketsSent", 0 )
  addEmptyAdslMib( "EOCPacketsReceived", 0 )
  addEmptyAdslMib( "EOCMessagesSent", 0 )
  addEmptyAdslMib( "EOCMessagesReceived", 0 )
  addEmptyAdslMib( "LastTransmittedDownstreamSignal", 0 )
  addEmptyAdslMib( "LastTransmittedUpstreamSignal", 0 )
  addEmptyAdslMib( "SNRMRMCds", 0 )
  addEmptyAdslMib( "SNRMRMCus", 0 )
  addEmptyAdslMib( "BITSRMCpsds", " " )
  addEmptyAdslMib( "BITSRMCpsus", " " )
  addEmptyAdslMib( "FEXTCANCELds", 0 )
  addEmptyAdslMib( "FEXTCANCELus", 0 )
  addEmptyAdslMib( "ETRds", 0 )
  addEmptyAdslMib( "ETRus", 0 )
  addEmptyAdslMib( "ATTETRds", 0 )
  addEmptyAdslMib( "ATTETRus", 0 )
  addEmptyAdslMib( "MINEFTR", 0 )
  addEmptyAdslMib( "UPBOKLEPb", " ")
  addEmptyAdslMib( "UPBOKLERPb", " ")
end

--- Function to return converted us/ds values from AdslMib
-- @param act     Function to call if conversion is needed. E.g adjustScale, decodeBooleanConfig.
-- @param value   ds/us value from adslMib
local function convertAdslValue(act, value)
  return act and act(value) or tostring(value or "")
end

--- Function which stores info from AdslMib into another table.
-- Table conversion stuff is done to keep the impact of the changes done
-- as small as possible on WebGUI/Transformer/IGD/...
-- @param adslmib AdslMib structure to read data from.
-- @param table   Table to store requested values.
-- @param index   Name of the parameter in the table.
-- @param ds      Name of the parameter in adslMib for downstream direction.
-- @param us      Name of the parameter in adslMib for upstream direction.
-- @param act     Function to call if conversion is needed. E.g adjustScale, decodeBooleanConfig.
local function addAdslMibValue( adslmib, table, index, ds, us, act )
  if us then
    table[index] = {}
    table[index]["ds"] = convertAdslValue(act, adslmib[ds])
    table[index]["us"] = convertAdslValue(act, adslmib[us])
  else
    table[index] = convertAdslValue(act, adslmib[ds])
  end
end

local function getLineNum(line)
  return line == "line1" and 1 or 0
end

--- Function to retrieve adslMib info.
-- To improve performance we only update the data after
-- 5 seconds between two consecutive calls.
-- @param lineid Line number.
-- @return sets global adslMib variable.
local function getAdslMibInfo(lineid)
  local line = getLineNum(lineid)
  local diff = os.time() - lastUpdateTime[line]
  if diff > 5 or diff < 0 then
    tmp = luabcm.getAdslMib(line)
    lastUpdateTime[line] = os.time()
    if tostring(tmp) == "-1" then
      createTableWithEmptyValues()
    else
      adslMib = tmp
    end
    -- update cache
    adslMibCache[line] = adslMib
  else
    -- no update, use cache
    adslMib = adslMibCache[line]
  end
end

-- map the parameter name with the corresponding upstream, downstream parameters and their call back conversion functions
local paramMap = {
  ["mode"] = {"Mode"},
  ["lrtr"] = {"LastRetrainReason"},
  ["lips"] = {"LastInitializationProcedureStatus"},
  ["maxrate"] = {"DownstreamMaxBitRate", "UpstreamMaxBitRate"},
  ["currentrate"] = {"DownstreamCurrRate", "UpstreamCurrRate"},
  ["linkpowerstate"] = {"PowerManagementState"},
  ["vdsl2profile"] = {"CurrentProfile"},
  ["tpstc"] = {"TpsTcBcm"},
  ["linestatus"] = {"LineStatus"},
  ["trainingstatus"] = {"TrainingStatus"},
  ["trellis"]= {"TRELLISds", "TRELLISus"},
  ["snr"] = {"DownstreamSNR", "UpstreamSNR", adjustScale},
  ["attn"] = {"DownstreamAttenuation", "UpstreamAttenuation", adjustScale},
  ["pwr"] = {"DownstreamPower", "UpstreamPower", adjustScale},
  ["framing_msgc"] = {"DownstreamFramingMSGc", "UpstreamFramingMSGc"},
  ["framing_b"] = {"DownstreamFramingB", "UpstreamFramingB"},
  ["framing_m"] = {"DownstreamFramingM", "UpstreamFramingM"},
  ["framing_t"] = {"DownstreamFramingT", "UpstreamFramingT"},
  ["framing_r"] = {"DownstreamFramingR", "UpstreamFramingR"},
  ["framing_s"] = {"DownstreamFramingS", "UpstreamFramingS"},
  ["framing_l"] = {"DownstreamFramingL", "UpstreamFramingL"},
  ["framing_d"] = {"DownstreamInterleaveDepth", "UpstreamInterleaveDepth"},
  ["framing_i"]= {"DownstreamFramingI", "UpstreamFramingI"},
  ["framing_n"] = {"DownstreamFramingN", "UpstreamFramingN"},
  ["framing_q"] = {"DownstreamFramingQ", "UpstreamFramingQ"},
  ["framing_V"] = {"DownstreamFramingV", "UpstreamFramingV"},
  ["framing_K"] = {"DownstreamFramingK", "UpstreamFramingK"},
  ["counters_ohf"] = {"OHFDs", "OHFUs"},
  ["counters_ohferr"] = {"OHFErrDs", "OHFErrUs"},
  ["counters_sf"] = {"SFDs", "SFUs"},
  ["counters_sferr"] = {"SFErrDs", "SFErrUs"},
  ["counters_rs"] = {"RSDs", "RSUs"},
  ["counters_rscorr"] = {"RSCorrDs", "RSCorrUs"},
  ["counters_rsuncorr"] = {"RSUnCorrDs", "RSUnCorrUs"},
  ["counters_hec"] = {"ShowtimeXTURHECErrors", "ShowtimeXTUCHECErrors"},
  ["counters_ocd"] = {"OCDDs", "OCDUs"},
  ["counters_lcd"] = {"LCDDs", "LCDUs"},
  ["counters_totalcells"] = {"BytesReceived", "BytesSent"},
  ["counters_datacells"] = {"PacketsReceived", "PacketsSent"},
  ["counters_dropcells"] = {"DiscardPacketsReceived", "DiscardPacketsSent"},
  ["counters_biterr"] = {"ErrorsReceived", "ErrorsSent"},
  ["counters_es"] = {"ShowtimeErroredSecsDs", "ShowtimeErroredSecsUs"},
  ["counters_ses"] = {"ShowtimeSeverelyErroredSecsDs", "ShowtimeSeverelyErroredSecsUs"},
  ["counters_uas"] = {"ShowtimeUnavailableSecsDs", "ShowtimeUnavailableSecsUs"},
  ["counters_as"] = {"ShowtimeAvailableSecs"},
  ["counters_inp"] = {"INPDs", "INPUs"},
  ["counters_inprein"] = {"INPReinDs", "INPReinUs"},
  ["counters_delay"] = {"DownstreamDelay", "UpstreamDelay"},
  ["counters_per"] = {"PERDs", "PERUs"},
  ["counters_or"] = {"ORDs", "ORUs"},
  ["counters_agr"] = {"AGRDs", "AGRUs"},
  ["counters_bitsw"] = {"BitswapDs", "BitswapUs"},
  ["counters_noisemargin"] = {"DownstreamNoiseMargin", "UpstreamNoiseMargin"},
  ["ginp_q"] = {"Qds", "Qus"},
  ["ginp_v"] = {"Vds", "Vus"},
  ["ginp_rxqueue"] = {"RxQueueds", "RxQueueus"},
  ["ginp_txqueue"] = {"TxQueueds", "TxQueueus"},
  ["ginp_rtxmode"] = {"RTxModeds", "RTxModeus"},
  ["ginp_lookback"] = {"LookBackds", "LookBackus"},
  ["ginp_rrcbits"] = {"RRCBitsds", "RRCBitsus"},
  ["ginp_rtxtx"] = {"RTxTxds", "RTxTxus"},
  ["ginp_rtxc"] = {"RTxCds", "RTxCus"},
  ["ginp_rtxuc"] = {"RTxUCds", "RTxUCus"},
  ["ginp_leftrs"] = {"LEFTRSds", "LEFTRSus"},
  ["ginp_mineftr"] = {"MinEFTRds", "MinEFTRus"},
  ["ginp_errfreebits"] = {"ErrFreeBitsds", "ErrFreeBitsus"},
  ["ginp_status"] = {"GINPStatus"},
  ["vectoring_directionmode"] = {"VectoringDirectionMode"},
  ["vectoring_rxbitswapmode"] = {"VectoringRxBitSwapMode"},
  ["vectoring_disablevnmode"] = {"VectoringDisableVNMode"},
  ["vectoring_vceaddress"] = {"VectoringVceAddress"},
  ["vectoring_cntespktsend"] = {"VectoringCntEsPktSend"},
  ["vectoring_cntespktdrop"] = {"VectoringCntEsPktDrop"},
  ["vectoring_cntesstatsend"] = {"VectoringCntEsStatSend"},
  ["vectoring_cntesstatdrop"] = {"VectoringCntEsStatDrop"},
  ["firmware_version"] = {"FirmwareVersion"},
  ["ACTINP"] = {"ACTINP"},
  ["ACTSNRMODE"] = {"ACTSNRMODEds", "ACTSNRMODEus"},
  ["ACTUALCE"] = {"ACTUALCE"},
  ["ActualInterleavingDelay"] = {"ActualInterleavingDelay"},
  ["AllowedProfiles"] = {"AllowedProfiles"},
  ["HLOGG"] = {"HLOGGds", "HLOGGus"},
  ["HLOGMT"] = {"HLOGMTds", "HLOGMTus"},
  ["HLOGps"] = {"HLOGpsds", "HLOGpsus"},
  ["INMCCds"] = {"INMCCds"},
  ["INMIATOds"] = {"INMIATOds"},
  ["INMIATSds"] = {"INMIATSds"},
  ["INMINPEQMODEds"] = {"INMINPEQMODEds"},
  ["INPREPORT"] = {"INPREPORT"},
  ["INTLVBLOCK"] = {"INTLVBLOCK"},
  ["INTLVDEPTH"] = {"INTLVDEPTH"},
  ["LATN"] = {"LATNds", "LATNus"},
  ["LIMITMASK"] = {"LIMITMASK"},
  ["LPATH"] = {"LPATH"},
  ["LSYMB"] = {"LSYMB"},
  ["LastStateTransmitted"] = {"LastStateTransmittedDownstream", "LastStateTransmittedUpstream"},
  ["LineEncoding"] = {"LineEncoding"},
  ["LinkEncapsulationSupported"] = {"LinkEncapsulationSupported"},
  ["LinkEncapsulationRequested"] = {"LinkEncapsulationRequested"},
  ["LinkEncapsulationUsed"] = {"LinkEncapsulationUsed"},
  ["LinkStatus"] = {"LinkStatus"},
  ["MREFPSD"] = {"MREFPSDds", "MREFPSDus"},
  ["NFEC"] = {"NFEC"},
  ["RFEC"] = {"RFEC"},
  ["QLNMT"] = {"QLNMTds", "QLNMTus"},
  ["QLNps"] = {"QLNpsds", "QLNpsus"},
  ["SATN"] = {"SATNds", "SATNus"},
  ["SNRG"] = {"SNRGds", "SNRGus"},
  ["SNRMT"] = {"SNRMTds", "SNRMTus"},
  ["SNRMpb"] = {"SNRMpbds", "SNRMpbus"},
  ["SNRps"] = {"SNRpsds", "SNRpsus"},
  ["StandardUsed"] = {"StandardUsed"},
  ["StandardsSupported"] = {"StandardsSupported"},
  ["SuccessFailureCause"] = {"SuccessFailureCause"},
  ["UPBOKLE"] = {"UPBOKLE"},
  ["UPBOKLER"] = {"UPBOKLER"},
  ["US0MASK"] = {"US0MASK"},
  ["VirtualNoisePSD"] = {"VirtualNoisePSDds", "VirtualNoisePSDus"},
  ["XTUCANSIRev"] = {"XTUCANSIRev"},
  ["XTUCANSIStd"] = {"XTUCANSIStd"},
  ["XTUCCountry"] = {"XTUCCountry"},
  ["XTUCVendor"] = {"XTUCVendor"},
  ["XTURANSIRev"] = {"XTURANSIRev"},
  ["XTURANSIStd"] = {"XTURANSIStd"},
  ["XTURCountry"] = {"XTURCountry"},
  ["XTURVendor"] = {"XTURVendor"},
  ["ACTATP"] = {"ACTATPds", "ACTATPus"},
  ["ACTPSD"] = {"ACTPSDds", "ACTPSDus"},
  ["BITSps"] = {"BITSpsds", "BITSpsus"},
  ["HLINps"] = {"HLINpsds", "HLINpsus"},
  ["EOCBytesSent"] = {"EOCBytesSent"},
  ["EOCBytesReceived"] = {"EOCBytesReceived"},
  ["EOCPacketsSent"] = {"EOCPacketsSent"},
  ["EOCPacketsReceived"] = {"EOCPacketsReceived"},
  ["EOCMessagesSent"] = {"EOCMessagesSent"},
  ["EOCMessagesReceived"] = {"EOCMessagesReceived"},
  ["LastTransmittedDownstreamSignal"] = {"LastTransmittedDownstreamSignal"},
  ["LastTransmittedUpstreamSignal"] = {"LastTransmittedUpstreamSignal"},
  ["SNRMRMC"] = {"SNRMRMCds" , "SNRMRMCus"},
  ["BITSRMCps"] = {"BITSRMCpsds", "BITSRMCpsus"},
  ["FEXTCANCEL"] = {"FEXTCANCELds", "FEXTCANCELus"},
  ["ETR"] = {"ETRds", "ETRus"},
  ["ATTETR"] = {"ATTETRds", "ATTETRus"},
  ["MINEFTR"] = {"MINEFTR"},
  ["UPBOKLEPb"] = {"UPBOKLEPb"},
  ["UPBOKLERPb"] = {"UPBOKLERPb"},
}

--- Retrieves the INFO values from the AdslMib.
-- @param lineid  Line number to retrieve data for.
-- @return Table which contains the different INFO values.
local function getInfoValuesFromAdslMib( lineid )
  local allvalues = {}
  getAdslMibInfo(lineid)
  allvalues.status = valueFromCmd(xdslctlinfo[lineid], "status")
  allvalues.linit = valueFromCmd(xdslctlinfo[lineid], "linit")
  for key, param in pairs(paramMap) do
    addAdslMibValue( adslMib, allvalues, key, param[1], param[2], param[3] )
  end
  allvalues.currentrate.channel = "0"
  return allvalues
end

--- Retrieves a sigle INFO value form the AdslMib.
-- @param key   Parameter name to retrieve data from
-- @param subkey Parameter subkey. E.g. "ds" for Downstream value.
-- @param lineid Line number.
-- @return String which contains the INFO value.
local function getInfoValueFromAdslMib( lineid, key, subkey )
  local getValue = {}
  getAdslMibInfo(lineid)
  if key == "status" or key == "linit" then
    return valueFromCmd( xdslctlinfo[lineid], key )
  end
  local param = paramMap[key] or {}
  addAdslMibValue( adslMib, getValue, key, param[1], param[2], param[3] )
  if subkey and subkey ~= "" then
    return getValue[key][subkey]
  end
  return getValue[key]
end

--- Retrieves periodic interval statistics from AdslMib.
-- @param lineid Line number to retrieve statistic for.
-- @return Table with the periodic interval statistics.
local function getStatsValuesFromAdslMib( lineid )
  local t={}

  getAdslMibInfo(lineid)

  t["total"] = {}
  t["currentquarter"] = {}
  t["previousquarter"] = {}
  t["currentday"] = {}
  t["previousday"] = {}
  t["sincesync"] = {}
  t["lastshowtime"] = {}

  addAdslMibValue( adslMib, t["total"], "fec", "TotalXTURFECErrors", "TotalXTUCFECErrors")
  addAdslMibValue( adslMib, t["total"], "crc", "TotalXTURCRCErrors", "TotalXTUCCRCErrors")
  addAdslMibValue( adslMib, t["total"], "hec", "TotalXTURHECErrors", "TotalXTUCHECErrors")
  addAdslMibValue( adslMib, t["total"], "es",  "TotalErroredSecsDs", "TotalErroredSecsUs")
  addAdslMibValue( adslMib, t["total"], "ses", "TotalSeverelyErroredSecsDs", "TotalSeverelyErroredSecsUs")
  addAdslMibValue( adslMib, t["total"], "uas", "TotalUnavailableSecsDs", "TotalUnavailableSecsUs")
  addAdslMibValue( adslMib, t["total"], "los", "TotalLossOfSignalSecsDs", "TotalLossOfSignalSecsUs")
  addAdslMibValue( adslMib, t["total"], "lof", "TotalLossOfFramingSecsDs", "TotalLossOfFramingSecsUs")
  addAdslMibValue( adslMib, t["total"], "lom", "TotalLossOfMarginSecsDs", "TotalLossOfMarginSecsUs")
  addAdslMibValue( adslMib, t["total"], "retr", "TotalRetrainCount")
  addAdslMibValue( adslMib, t["total"], "time", "TotalTime")
  addAdslMibValue( adslMib, t["total"], "start", "TotalStart")
  addAdslMibValue( adslMib, t["currentquarter"], "fec", "QuarterHourXTURFECErrors", "QuarterHourXTUCFECErrors")
  addAdslMibValue( adslMib, t["currentquarter"], "crc", "QuarterHourXTURCRCErrors", "QuarterHourXTUCCRCErrors")
  addAdslMibValue( adslMib, t["currentquarter"], "hec", "QuarterHourXTURHECErrors", "QuarterHourXTUCHECErrors")
  addAdslMibValue( adslMib, t["currentquarter"], "es",  "QuarterHourErroredSecsDs", "QuarterHourErroredSecsUs")
  addAdslMibValue( adslMib, t["currentquarter"], "ses", "QuarterHourSeverelyErroredSecsDs", "QuarterHourSeverelyErroredSecsUs")
  addAdslMibValue( adslMib, t["currentquarter"], "uas", "QuarterHourUnavailableSecsDs", "QuarterHourUnavailableSecsUs")
  addAdslMibValue( adslMib, t["currentquarter"], "los", "QuarterHourLossOfSignalSecsDs", "QuarterHourLossOfSignalSecsUs")
  addAdslMibValue( adslMib, t["currentquarter"], "lof", "QuarterHourLossOfFramingSecsDs", "QuarterHourLossOfFramingSecsUs")
  addAdslMibValue( adslMib, t["currentquarter"], "lom", "QuarterHourLossOfMarginSecsDs", "QuarterHourLossOfMarginSecsUs")
  addAdslMibValue( adslMib, t["currentquarter"], "retr", "QuarterHourRetrainCount")
  addAdslMibValue( adslMib, t["currentquarter"], "time", "QuarterHourTime")
  addAdslMibValue( adslMib, t["currentquarter"], "start", "QuarterHourStart")
  addAdslMibValue( adslMib, t["previousquarter"], "fec", "PreviousQuarterHourXTURFECErrors", "PreviousQuarterHourXTUCFECErrors")
  addAdslMibValue( adslMib, t["previousquarter"], "crc", "PreviousQuarterHourXTURCRCErrors", "PreviousQuarterHourXTUCCRCErrors")
  addAdslMibValue( adslMib, t["previousquarter"], "hec", "PreviousQuarterHourXTURHECErrors", "PreviousQuarterHourXTUCHECErrors")
  addAdslMibValue( adslMib, t["previousquarter"], "es",  "PreviousQuarterHourErroredSecsDs", "PreviousQuarterHourErroredSecsUs")
  addAdslMibValue( adslMib, t["previousquarter"], "ses", "PreviousQuarterHourSeverelyErroredSecsDs", "PreviousQuarterHourSeverelyErroredSecsUs")
  addAdslMibValue( adslMib, t["previousquarter"], "uas", "PreviousQuarterHourUnavailableSecsDs", "PreviousQuarterHourUnavailableSecsUs")
  addAdslMibValue( adslMib, t["previousquarter"], "los", "PreviousQuarterHourLossOfSignalSecsDs", "PreviousQuarterHourLossOfSignalSecsUs")
  addAdslMibValue( adslMib, t["previousquarter"], "lof", "PreviousQuarterHourLossOfFramingSecsDs", "PreviousQuarterHourLossOfFramingSecsUs")
  addAdslMibValue( adslMib, t["previousquarter"], "lom", "PreviousQuarterHourLossOfMarginSecsDs", "PreviousQuarterHourLossOfMarginSecsUs")
  addAdslMibValue( adslMib, t["previousquarter"], "retr", "PreviousQuarterHourRetrainCount")
  addAdslMibValue( adslMib, t["previousquarter"], "time", "PreviousQuarterHourTime")
  addAdslMibValue( adslMib, t["currentday"], "fec", "CurrentDayXTURFECErrors", "CurrentDayXTUCFECErrors")
  addAdslMibValue( adslMib, t["currentday"], "crc", "CurrentDayXTURCRCErrors", "CurrentDayXTUCCRCErrors")
  addAdslMibValue( adslMib, t["currentday"], "hec", "CurrentDayXTURHECErrors", "CurrentDayXTUCHECErrors")
  addAdslMibValue( adslMib, t["currentday"], "es",  "CurrentDayErroredSecsDs", "CurrentDayErroredSecsUs")
  addAdslMibValue( adslMib, t["currentday"], "ses", "CurrentDaySeverelyErroredSecsDs", "CurrentDaySeverelyErroredSecsUs")
  addAdslMibValue( adslMib, t["currentday"], "uas", "CurrentDayUnavailableSecsDs", "CurrentDayUnavailableSecsUs")
  addAdslMibValue( adslMib, t["currentday"], "los", "CurrentDayLossOfSignalSecsDs", "CurrentDayLossOfSignalSecsUs")
  addAdslMibValue( adslMib, t["currentday"], "lof", "CurrentDayLossOfFramingSecsDs", "CurrentDayLossOfFramingSecsUs")
  addAdslMibValue( adslMib, t["currentday"], "lom", "CurrentDayLossOfMarginSecsDs", "CurrentDayLossOfMarginSecsUs")
  addAdslMibValue( adslMib, t["currentday"], "retr", "CurrentDayRetrainCount")
  addAdslMibValue( adslMib, t["currentday"], "time", "CurrentDayTime")
  addAdslMibValue( adslMib, t["currentday"], "start", "CurrentDayStart")
  addAdslMibValue( adslMib, t["lastshowtime"], "fec", "LastShowtimeXTURFECErrors", "LastShowtimeXTUCFECErrors")
  addAdslMibValue( adslMib, t["lastshowtime"], "crc", "LastShowtimeXTURCRCErrors", "LastShowtimeXTUCCRCErrors")
  addAdslMibValue( adslMib, t["lastshowtime"], "hec", "LastShowtimeXTURHECErrors", "LastShowtimeXTUCHECErrors")
  addAdslMibValue( adslMib, t["lastshowtime"], "es",  "LastShowtimeErroredSecsDs", "LastShowtimeErroredSecsUs")
  addAdslMibValue( adslMib, t["lastshowtime"], "ses", "LastShowtimeSeverelyErroredSecsDs", "LastShowtimeSeverelyErroredSecsUs")
  addAdslMibValue( adslMib, t["lastshowtime"], "uas", "LastShowtimeUnavailableSecsDs", "LastShowtimeUnavailableSecsUs")
  addAdslMibValue( adslMib, t["lastshowtime"], "los", "LastShowtimeLossOfSignalSecsDs", "LastShowtimeLossOfSignalSecsUs")
  addAdslMibValue( adslMib, t["lastshowtime"], "lof", "LastShowtimeLossOfFramingSecsDs", "LastShowtimeLossOfFramingSecsUs")
  addAdslMibValue( adslMib, t["lastshowtime"], "lom", "LastShowtimeLossOfMarginSecsDs", "LastShowtimeLossOfMarginSecsUs")
  addAdslMibValue( adslMib, t["lastshowtime"], "retr", "LastShowtimeRetrainCount")
  addAdslMibValue( adslMib, t["lastshowtime"], "time", "LastShowtimeTime")
  addAdslMibValue( adslMib, t["lastshowtime"], "start", "LastShowtimeStart")
  addAdslMibValue( adslMib, t["previousday"], "fec", "PreviousDayXTURFECErrors", "PreviousDayXTUCFECErrors")
  addAdslMibValue( adslMib, t["previousday"], "crc", "PreviousDayXTURCRCErrors", "PreviousDayXTUCCRCErrors")
  addAdslMibValue( adslMib, t["previousday"], "hec", "PreviousDayXTURHECErrors", "PreviousDayXTUCHECErrors")
  addAdslMibValue( adslMib, t["previousday"], "es",  "PreviousDayErroredSecsDs", "PreviousDayErroredSecsUs")
  addAdslMibValue( adslMib, t["previousday"], "ses", "PreviousDaySeverelyErroredSecsDs", "PreviousDaySeverelyErroredSecsUs")
  addAdslMibValue( adslMib, t["previousday"], "uas", "PreviousDayUnavailableSecsDs", "PreviousDayUnavailableSecsUs")
  addAdslMibValue( adslMib, t["previousday"], "los", "PreviousDayLossOfSignalSecsDs", "PreviousDayLossOfSignalSecsUs")
  addAdslMibValue( adslMib, t["previousday"], "lof", "PreviousDayLossOfFramingSecsDs", "PreviousDayLossOfFramingSecsUs")
  addAdslMibValue( adslMib, t["previousday"], "lom", "PreviousDayLossOfMarginSecsDs", "PreviousDayLossOfMarginSecsUs")
  addAdslMibValue( adslMib, t["previousday"], "retr", "PreviousDayRetrainCount")
  addAdslMibValue( adslMib, t["previousday"], "time", "PreviousDayTime")
  addAdslMibValue( adslMib, t["sincesync"], "fec", "ShowtimeXTURFECErrors", "ShowtimeXTUCFECErrors")
  addAdslMibValue( adslMib, t["sincesync"], "crc", "ShowtimeXTURCRCErrors", "ShowtimeXTUCCRCErrors")
  addAdslMibValue( adslMib, t["sincesync"], "hec", "ShowtimeXTURHECErrors", "ShowtimeXTUCHECErrors")
  addAdslMibValue( adslMib, t["sincesync"], "es",  "ShowtimeErroredSecsDs", "ShowtimeErroredSecsUs")
  addAdslMibValue( adslMib, t["sincesync"], "ses", "ShowtimeSeverelyErroredSecsDs", "ShowtimeSeverelyErroredSecsUs")
  addAdslMibValue( adslMib, t["sincesync"], "uas", "ShowtimeUnavailableSecsDs", "ShowtimeUnavailableSecsUs")
  addAdslMibValue( adslMib, t["sincesync"], "los", "ShowtimeLossOfSignalSecsDs", "ShowtimeLossOfSignalSecsUs")
  addAdslMibValue( adslMib, t["sincesync"], "lof", "ShowtimeLossOfFramingSecsDs", "ShowtimeLossOfFramingSecsUs")
  addAdslMibValue( adslMib, t["sincesync"], "lom", "ShowtimeLossOfMarginSecsDs", "ShowtimeLossOfMarginSecsUs")
  addAdslMibValue( adslMib, t["sincesync"], "retr", "ShowtimeRetrainCount")
  addAdslMibValue( adslMib, t["sincesync"], "time", "ShowtimeTime")
  addAdslMibValue( adslMib, t["sincesync"], "start", "ShowtimeStart")
 -- g.fast periodic statistics
  addAdslMibValue( adslMib, t["total"], "bswStarted", "TotalBSWStartedDs", "TotalBSWStartedUs" )
  addAdslMibValue( adslMib, t["total"], "bswCompleted", "TotalBSWCompletedDs", "TotalBSWCompletedUs" )
  addAdslMibValue( adslMib, t["total"], "sraStarted", "TotalSRAStartedDs", "TotalSRAStartedUs" )
  addAdslMibValue( adslMib, t["total"], "sraCompleted", "TotalSRACompletedDs", "TotalSRACompletedUs" )
  addAdslMibValue( adslMib, t["total"], "fraStarted", "TotalFRAStartedDs", "TotalFRAStartedUs" )
  addAdslMibValue( adslMib, t["total"], "fraCompleted", "TotalFRACompletedDs", "TotalFRACompletedUs" )
  addAdslMibValue( adslMib, t["total"], "rpaStarted", "TotalRPAStartedDs", "TotalRPAStartedUs" )
  addAdslMibValue( adslMib, t["total"], "rpaCompleted", "TotalRPACompletedDs", "TotalRPACompletedUs" )
  addAdslMibValue( adslMib, t["total"], "tigaStarted", "TotalTIGAStartedDs", "TotalTIGAStartedUs" )
  addAdslMibValue( adslMib, t["total"], "tigaCompleted", "TotalTIGACompletedDs", "TotalTIGACompletedUs" )
  addAdslMibValue( adslMib, t["total"], "rtx", "TotalRTXUC", "TotalRTXTX" )
  addAdslMibValue( adslMib, t["sincesync"], "bswStarted", "ShowtimeBSWStartedDs", "ShowtimeBSWStartedUs" )
  addAdslMibValue( adslMib, t["sincesync"], "bswCompleted", "ShowtimeBSWCompletedDs", "ShowtimeBSWCompletedUs" )
  addAdslMibValue( adslMib, t["sincesync"], "sraStarted", "ShowtimeSRAStartedDs", "ShowtimeSRAStartedUs" )
  addAdslMibValue( adslMib, t["sincesync"], "sraCompleted", "ShowtimeSRACompletedDs", "ShowtimeSRACOmpletedUs" )
  addAdslMibValue( adslMib, t["sincesync"], "fraStarted", "ShowtimeFRAStartedDs", "ShowtimeFRAStartedUs" )
  addAdslMibValue( adslMib, t["sincesync"], "fraCompleted", "ShowtimeFRACompletedDs", "ShowtimeFRACompletedUs" )
  addAdslMibValue( adslMib, t["sincesync"], "rpaStarted", "ShowtimeRPAStartedDs", "ShowtimeRPAStartedUs" )
  addAdslMibValue( adslMib, t["sincesync"], "rpaCompleted", "ShowtimeRPACompletedDs", "ShowtimeRPACompletedUs" )
  addAdslMibValue( adslMib, t["sincesync"], "tigaStarted", "ShowtimeTIGAStartedDs", "ShowtimeTIGAStartedUs" )
  addAdslMibValue( adslMib, t["sincesync"], "tigaCompleted", "ShowtimeTIGACompletedDs", "ShowtimeTIGACompletedUs" )
  addAdslMibValue( adslMib, t["sincesync"], "rtx", "ShowtimeRTXUC", "ShowtimeRTXTX" )
  addAdslMibValue( adslMib, t["currentday"], "bswStarted", "CurrentDayBSWStartedDs", "CurrentDayBSWStartedUs" )
  addAdslMibValue( adslMib, t["currentday"], "bswCompleted", "CurrentDayBSWCompletedDs", "CurrentDayBSWCompletedUs" )
  addAdslMibValue( adslMib, t["currentday"], "sraStarted", "CurrentDaySRAStartedDs", "CurrentDaySRAStartedUs" )
  addAdslMibValue( adslMib, t["currentday"], "sraCompleted", "CurrentDaySRACompletedDs", "CurrentDaySRACompletedUs" )
  addAdslMibValue( adslMib, t["currentday"], "fraStarted", "CurrentDayFRAStartedDs", "CurrentDayFRAStartedUs" )
  addAdslMibValue( adslMib, t["currentday"], "fraCompleted", "CurrentDayFRACompletedDs", "CurrentDayFRACompletedUs" )
  addAdslMibValue( adslMib, t["currentday"], "rpaStarted", "CurrentDayRPAStartedDs", "CurrentDayRPAStartedUs" )
  addAdslMibValue( adslMib, t["currentday"], "rpaCompleted", "CurrentDayRPACompletedDs", "CurrentDayRPACompletedUs" )
  addAdslMibValue( adslMib, t["currentday"], "tigaStarted", "CurrentDayTIGAStartedDs", "CurrentDayTIGAStartedUs" )
  addAdslMibValue( adslMib, t["currentday"], "tigaCompleted", "CurrentDayTIGACompletedDs", "CurrentDayTIGACompletedUs" )
  addAdslMibValue( adslMib, t["currentday"], "rtx", "CurrentDayRTXUC", "CurrentDayRTXTX" )
  addAdslMibValue( adslMib, t["lastshowtime"], "bswStarted", "LastShowtimeBSWStartedDs", "LastShowtimeBSWStartedUs" )
  addAdslMibValue( adslMib, t["lastshowtime"], "bswCompleted", "LastShowtimeBSWCompletedDs", "LastShowtimeBSWCompletedUs" )
  addAdslMibValue( adslMib, t["lastshowtime"], "sraStarted", "LastShowtimeSRAStartedDs", "LastShowtimeSRAStartedUs" )
  addAdslMibValue( adslMib, t["lastshowtime"], "sraCompleted", "LastShowtimeSRACompletedDs", "LastShowtimeSRACOmpletedUs" )
  addAdslMibValue( adslMib, t["lastshowtime"], "fraStarted", "LastShowtimeFRAStartedDs", "LastShowtimeFRAStartedUs" )
  addAdslMibValue( adslMib, t["lastshowtime"], "fraCompleted", "LastShowtimeFRACompletedDs", "LastShowtimeFRACompletedUs" )
  addAdslMibValue( adslMib, t["lastshowtime"], "rpaStarted", "LastShowtimeRPAStartedDs", "LastShowtimeRPAStartedUs" )
  addAdslMibValue( adslMib, t["lastshowtime"], "rpaCompleted", "LastShowtimeRPACompletedDs", "LastShowtimeRPACompletedUs" )
  addAdslMibValue( adslMib, t["lastshowtime"], "tigaStarted", "LastShowtimeTIGAStartedDs", "LastShowtimeTIGAStartedUs" )
  addAdslMibValue( adslMib, t["lastshowtime"], "tigaCompleted", "LastShowtimeTIGACompletedDs", "LastShowtimeTIGACompletedUs" )
  addAdslMibValue( adslMib, t["lastshowtime"], "rtx", "LastShowtimeRTXUC", "LastShowtimeRTXTX" )
  addAdslMibValue( adslMib, t["currentquarter"], "bswStarted", "QuarterHourBSWStartedDs", "QuarterHourBSWStartedUs" )
  addAdslMibValue( adslMib, t["currentquarter"], "bswCompleted", "QuarterHourBSWCompletedDs", "QuarterHourBSWCompletedUs" )
  addAdslMibValue( adslMib, t["currentquarter"], "sraStarted", "QuarterHourSRAStartedDs", "QuarterHourSRAStartedUs" )
  addAdslMibValue( adslMib, t["currentquarter"], "sraCompleted", "QuarterHourSRACompletedDs", "QuarterHourSRACompletedUs" )
  addAdslMibValue( adslMib, t["currentquarter"], "fraStarted", "QuarterHourFRAStartedDs", "QuarterHourFRAStartedUs" )
  addAdslMibValue( adslMib, t["currentquarter"], "fraCompleted", "QuarterHourFRACompletedDs", "QuarterHourFRACompletedUs" )
  addAdslMibValue( adslMib, t["currentquarter"], "rpaStarted", "QuarterHourRPAStartedDs", "QuarterHourRPAStartedUs" )
  addAdslMibValue( adslMib, t["currentquarter"], "rpaCompleted", "QuarterHourRPACompletedDs", "QuarterHourRPACompletedUs" )
  addAdslMibValue( adslMib, t["currentquarter"], "tigaStarted", "QuarterHourTIGAStartedDs", "QuarterHourTIGAStartedUs" )
  addAdslMibValue( adslMib, t["currentquarter"], "tigaCompleted", "QuarterHourTIGACompletedDs", "QuarterHourTIGACompletedUs" )
  addAdslMibValue( adslMib, t["currentquarter"], "rtx", "QuarterHourRTXUC", "QuarterHourRTXTX" )
  return t
end

--- Function to retrieve profile information from AdslMib.
-- @param lineid Line number to retrieve data for.
-- @return Table which contains the profile information values.
local function getProfileValuesFromAdslMib( lineid )
  local profileData = {}

  getAdslMibInfo(lineid)

  addAdslMibValue( adslMib, profileData, "mod_g.dmt", "GDMT", nil, decodeBooleanConfig )
  addAdslMibValue( adslMib, profileData, "mod_g.lite", "GLITE", nil, decodeBooleanConfig )
  addAdslMibValue( adslMib, profileData, "mod_t1.413", "T1413", nil, decodeBooleanConfig )
  addAdslMibValue( adslMib, profileData, "mod_adsl2", "ADSL2", nil, decodeBooleanConfig )
  addAdslMibValue( adslMib, profileData, "mod_annexl", "ANNEXL", nil, decodeBooleanConfig )
  addAdslMibValue( adslMib, profileData, "mod_adsl2plus", "ADSL2P", nil, decodeBooleanConfig )
  addAdslMibValue( adslMib, profileData, "mod_annexm", "ANNEXM", nil, decodeBooleanConfig )
  addAdslMibValue( adslMib, profileData, "mod_vdsl2", "VDSL2", nil, decodeBooleanConfig )
  addAdslMibValue( adslMib, profileData, "mod_gfast", "GFAST", nil, decodeBooleanConfig )
  addAdslMibValue( adslMib, profileData, "phonelinepair", "LinePair" )
  addAdslMibValue( adslMib, profileData, "cap_bitswap", "Bitswap", nil, decodeBooleanConfig )
  addAdslMibValue( adslMib, profileData, "cap_sra", "SRA", nil, decodeBooleanConfig )
  addAdslMibValue( adslMib, profileData, "cap_trellis", "Trellis", nil, decodeBooleanConfig )
  addAdslMibValue( adslMib, profileData, "cap_sesdrop", "SESDrop", nil, decodeBooleanConfig )
  addAdslMibValue( adslMib, profileData, "cap_cominmgn", "CoMinMgn", nil, decodeBooleanConfig )
  addAdslMibValue( adslMib, profileData, "cap_24k", "24k", nil, decodeBooleanConfig )
  addAdslMibValue( adslMib, profileData, "cap_phyrexmtus", "PhyReXmtUs", nil, decodeBooleanConfig )
  addAdslMibValue( adslMib, profileData, "cap_phyrexmtds", "PhyReXmtDs", nil, decodeBooleanConfig )
  addAdslMibValue( adslMib, profileData, "cap_tpstc", "TpsTc", nil, decodeBooleanConfig )
  addAdslMibValue( adslMib, profileData, "cap_monitortone", "MonitorTone", nil, decodeBooleanConfig )
  addAdslMibValue( adslMib, profileData, "cap_dynamicd", "DynamicD", nil, decodeBooleanConfig )
  addAdslMibValue( adslMib, profileData, "cap_dynamicf", "DynamicF", nil, decodeBooleanConfig )
  addAdslMibValue( adslMib, profileData, "cap_v43", "V43", nil, decodeBooleanConfig )
  addAdslMibValue( adslMib, profileData, "cap_sos", "SOS", nil, decodeBooleanConfig )
  addAdslMibValue( adslMib, profileData, "cap_trainingmargin", "TrainingMargin", nil, decodeBooleanConfig )
  addAdslMibValue( adslMib, profileData, "cap_ginpus", "GINPUs", nil, decodeBooleanConfig )
  addAdslMibValue( adslMib, profileData, "cap_ginpds", "GINPDs", nil, decodeBooleanConfig )
  addAdslMibValue( adslMib, profileData, "cap_ikns", "IKNS", nil, decodeBooleanConfig )

  return profileData
end

--- Function to retrieve profile information from AdslMib.
-- @param lineid Line number to retrieve data for.
-- @return Table which contains the profile information values.
local function getPerBandValuesFromAdslMib( lineid )
  local peerBand = {}
  getAdslMibInfo(lineid)

  addAdslMibValue( adslMib, peerBand, "attn", "LineAttenuationPBDownstream", "LineAttenuationPBUpstream")
  return peerBand
end

--- Function to retrieve Non Linear Noise Monitoring information.
-- @param lineid Line number to retrieve data for.
-- @return Table which contains the NLNM results.
local function getNLNMInfo( lineid )
  local line = getLineNum(lineid)

  local nlnmData = luabcm.getNLNM(line)
  local nlnm = {}

  nlnm["NonLinearityFlag"] = nlnmData["NonLinearityFlag"] and tostring(nlnmData["NonLinearityFlag"]) or "0"
  nlnm["NumberOfAffectedBins"] = nlnmData["NumberOfAffectedBins"] and tostring(nlnmData["NumberOfAffectedBins"]) or "0"
  nlnm["ThresholdNumberOfBins"] = nlnmData["ThresholdNumberOfBins"] and tostring(nlnmData["ThresholdNumberOfBins"]) or "0"
  nlnm["ENR"] = nlnmData["ENR"] and tostring(nlnmData["ENR"]) or "0"
  nlnm["ThresholdValue"] = nlnmData["ThresholdValue"] and tostring(nlnmData["ThresholdValue"]) or "0"

  return nlnm
end

--- Function to set the NLNM threshold value.
-- @param lineid Line number to set the threshold value for.
-- @param value New NLNM threshold value.
-- @return none.
local function setNLNMThresholdValue( lineid, value )
  local line = getLineNum(lineid)
  luabcm.setNLNM( line, tonumber(value) )
end

--- Function to retrieve Bridge Tap Detection results.
-- @param lineid Line number to retrieve data for.
-- @return Table which contains the NLNM results.
local function getBridgeTapDetectionInfo( lineid )
  local line = getLineNum(lineid)

  local bridgeTapData = luabcm.getBTDetection(line)
  local bridgeTap = {}

  bridgeTap["BridgeTapDetected"] = bridgeTapData["BridgeTapDetected"] and tostring(bridgeTapData["BridgeTapDetected"]) or "0"
  bridgeTap["LocalMinimumTone"] = bridgeTapData["LocalMinimumTone"] and tostring(bridgeTapData["LocalMinimumTone"]) or "0"
  bridgeTap["BridgeTapDistance"] = bridgeTapData["BridgeTapDistance"] and tostring(bridgeTapData["BridgeTapDistance"]) or "0"
  bridgeTap["BitrateLoss"] = bridgeTapData["BitrateLoss"] and tostring(bridgeTapData["BitrateLoss"]) or "0"

  return bridgeTap
end

--- function to get single info value from AdslMib.
-- @param key       key (string) as e.g. linestatus,attn,snr.
-- @param subkey    subkey (string) ds for Downstream, us for Upstream.
-- @param defaultvalue deprecated.
-- @param lineid    Line number to retrieve data from.
function M.infoValue( key, subkey, defaultvalue, lineid )
  return getInfoValueFromAdslMib( lineid, key, subkey )
end

--- function to get list of info values from AdslMib.
-- @param keylist   deprecated.
-- @param lineid    Line number to retrieve data from.
function M.infoValueList( keylist, lineid )
  return getInfoValuesFromAdslMib(lineid)
end

--- function to get single profile value from AdslMib.
-- @param key       key (string) as in mod_vdsl2,cap_sos,...
-- @param subkey    subkey (string) useless. No Upstream/Downstream.
-- @param defaultvalue deprecated.
-- @param lineid    Line number to retrieve data from.
function M.profileValue( key, subkey, defaultvalue, lineid )
  local profile = getProfileValuesFromAdslMib( lineid )
  return subkey and profile[key][subkey] or profile[key]
end

--- function to get a list of profile values from the AdslMib.
-- @param keylist   deprecated
-- @param lineid    Line number to retrieve data from.
function M.profileValueList( keylist, lineid )
  return getProfileValuesFromAdslMib( lineid )
end

--- function to get list of periodic interval statistics from the AdslMib.
-- @param keylist   Key as in currentday,sincesync,...
-- @param lineid    Line number to retrieve data from.
function M.statsIntervalValueList( keylist, lineid )
  return getStatsValuesFromAdslMib(lineid)
end

--- function to get a single periodic interval value from the AdslMib.
-- @param section     The stats section (string), one of the keys in xdslctlstatstimewindows
-- @param key         The stat key (string), one of the keys in xdslstatskeys
-- @param direction   The direction for the stats, a string "us" (Upstream) or "ds"
--                    (Downstream)
-- @param lineid      Line number to retrieve data from.
function M.stats( section, key, direction, lineid )
  local periodicInterval = getStatsValuesFromAdslMib(lineid)
  if direction and direction ~= "" then
    return periodicInterval[section][key][direction]
  end
  return periodicInterval[section][key]
end

--- Function to get all the values from the AdslMib.
-- @return A table with all the stats,capabilities,etc...
function M.allstats( lineid )
  return getStatsValuesFromAdslMib(lineid)
end

--- function to get single value from xdslctl info --pbParams
-- @param key key (string) as in xdslctlpbParams.lookup
-- @param subkey subkey (string) as in xdslctlpbParams.lookup[key].subkeys
function M.infoPbParamsValue(key, subkey, defaultvalue, lineid)
  local pbData = getPerBandValuesFromAdslMib(lineid)
  return subkey and pbData[key][subkey] or pbData[key]
end

--- Function to get all the values form NLNM.
-- @return A table with all the NLNM values.
function M.getNLNM( lineid )
  return getNLNMInfo(lineid)
end

--- Function to retrieve a single NLNM value.
-- @param section     The stats section (string), one of the keys in xdslctlstatstimewindows
-- @param key         The stat key (string), one of the keys in xdslstatskeys
-- @param direction   The direction for the stats, a string "us" (Upstream) or "ds"
--                    (Downstream)
-- @param lineid      Line number to retrieve data from.
function M.getNLNMValue( key, subkey, defaultvalue, lineid )
  local nlnm = getNLNMInfo(lineid)
  return subkey and nlnm[key][subkey] or nlnm[key]
end

--- Function to set the NLNM Threshold value.
-- @param value   New value for the threshold.
-- @param lineid  Line number.
function M.setNLNMThreshold( value, lineid )
  setNLNMThresholdValue( lineid, value )
end

--- Function to retrieve Bridge Tap Detection results.
-- @param lineId  Line number.
-- @return Table with the Bridge Tap Detection results.
function M.getBridgeTapInfo( lineid )
  return getBridgeTapDetectionInfo(lineid)
end

--- Retrieves a single Bridge Tap result.
-- @param key           The stat key (string), one of the keys in Bridge Tap Detection Info
-- @param subkey        Upstream or Downstream or nil if not used.
-- @param defaultvalue  The default value.
-- @param lineId        Dsl Line number.
function M.getBridgeTapInfoValue( key, subkey, defaultvalue, lineid )
  local bridgeTap = getBridgeTapDetectionInfo(lineid)
  return subkey and bridgeTap[key][subkey] or bridgeTap[key]
end

---function to retrieve the BitLoading information.
-- @param lineid     Line number to retrieve the bitloading from.
-- @return String containing both US/DS bitloading info. Values are
--         separated with a comma.
function M.getBitLoading( lineid )
  getAdslMibInfo(lineid)
  return adslMib["BitLoading"]
end

--- Function to check if bonding support is enabled.
-- @return True if bonding support is enabled. False otherwise.
function M.isBondingSupported()
  local supported = uci_helper.get_from_uci({config= "xdsl", sectionname="dsl0", option="bondingsupport", default="0"})
  if supported == "1" then
    return true
  end
  return false
end

return M
