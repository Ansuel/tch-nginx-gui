gettext.textdomain('webui-wireguard')

local client_profile = "/tmp/modgui-wireguard-client.conf"
local client_name_file = "/tmp/modgui-wireguard-client.name"

local profile_file = io.open(client_profile, "r")
if not profile_file then
  ngx.status = ngx.HTTP_NOT_FOUND
  ngx.say(T"Generate a client key pair first.")
  return ngx.exit(ngx.HTTP_NOT_FOUND)
end

local profile = profile_file:read("*a") or ""
profile_file:close()

local download_name = "modgui-wireguard-client"
local name_file = io.open(client_name_file, "r")
if name_file then
  local candidate = (name_file:read("*l") or ""):gsub("[^A-Za-z0-9_.-]", "-")
  name_file:close()
  if candidate ~= "" then download_name = candidate end
end

ngx.header.content_type = "text/plain"
ngx.header.content_disposition = 'attachment; filename="' .. download_name .. '.conf"'
ngx.header.cache_control = "no-store"
ngx.print(profile)
return ngx.exit(ngx.HTTP_OK)
