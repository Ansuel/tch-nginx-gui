local models = {
 ["DGA4130"] = "AGTEF",
 ["DGA4132"] = "AGTHP",
 ["MediaAccess DGA4331"] = "AGTHF",
 ["MediaAccess DGA4131FWB"] = "DGA4131FWB",
 ["FGA221DFWB"] = "NeXXt One",
 ["Technicolor FGA221DFWB"] = "NeXXt One",
 ["MediaAccess TG589vac"] = "TG799vac",
 ["Technicolor TG799vac"] = "TG799vac",
 ["Technicolor TG800vac"] = "TG800vac",
 ["Technicolor TG789vac V2"] = "TG789vac",
 ["MediaAccess TG789vac v2"] = "TG789vac",
 ["Technicolor TG789vac Xtream_IAD"] = "TG789vac",
 ["Technicolor TG789vac Xtream_MOS"] = "TG789vac",
 ["MediaAccess TG789MYRvac v2 HP"] = "TG789vac",
 ["TG789vac v3"] = "AGTEF", --just because have similar aspect for image
 ["Technicolor TG788vn"] = "TG788vn",
 ["MediaAccess TG788vn v2"] = "TG788vn",
 ["Technicolor DJA0230TLS"] = "DJA0230",
 ["Technicolor DJA0231"] = "DJA0231",
}

function models.gateway_image(model, extension)
  model = model:match("^%s*(.-)%s*$")
  local short = model:gsub("^MediaAccess%s+", ""):gsub("^Technicolor%s+", "")
  local alias = models[model] or models[short] or models["MediaAccess " .. short] or models["Technicolor " .. short]
  local token = type(alias) == "string" and alias or short
  if token:match("^[%w _%-]+$") then
    local name = "gateway_" .. token .. "." .. extension
    local file = io.open("/www/docroot/img/" .. name, "r")
    if file then
      file:close()
      return name
    end
  end
end

return models
