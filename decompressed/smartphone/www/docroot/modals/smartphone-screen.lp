--pretranslated: do not change this file
-- Access is restricted to the same roles as the Smartphone app by web.ruleset_main.
ngx.header["Cache-Control"] = "no-store, private"
ngx.header["Pragma"] = "no-cache"
ngx.header["X-Content-Type-Options"] = "nosniff"
local file = io.open("/var/run/modgui-smartphone-screen/frame.png", "rb")
if not file then return ngx.exit(ngx.HTTP_NOT_FOUND) end
ngx.header.content_type = "image/png"
while true do
    local chunk = file:read(32768)
    if not chunk then break end
    ngx.print(chunk)
end
file:close()
return ngx.exit(ngx.HTTP_OK)
