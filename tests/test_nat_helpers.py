"""Check the NAT helper card and modal against both transformer schemas."""
from pathlib import Path
import shutil
import subprocess
import unittest


ROOT = Path(__file__).resolve().parents[1]
LUA = shutil.which("lua")
CARD = ROOT / "decompressed/gui_file/www/cards/092_natalghelper.lp"
MODAL = ROOT / "decompressed/gui_file/www/docroot/modals/nat-alg-helper-modal.lp"


@unittest.skipUnless(LUA, "Lua interpreter required")
class NatHelpersTest(unittest.TestCase):
    def run_page(self, path, modern, helpers):
        script = r'''
local path, modern, count = arg[1], arg[2] == "true", tonumber(arg[3])
local output = {}
local native_format = string.format
string.format = function(template, ...)
    return native_format(template:gsub("%%1%$s", "%%s"):gsub("%%2%$d", "%%d"), ...)
end
gettext = {textdomain = function() end}
T = function(value) return value end
N = function(one, many, number) return number == 1 and one or many end
ngx = {ctx = {session = {hasAccess = function() return true end}},
       print = function(...) for _, value in ipairs({...}) do output[#output + 1] = tostring(value) end end}
local proxy = {
    getPN = function(path) assert(path == "uci.firewall_helpers.helper."); return modern and {"1"} or {} end,
    get = function(path)
        assert(path == (modern and "uci.firewall_helpers.helper." or "uci.firewall.helper."))
        return {}
    end,
}
package.preload.datamodel = function() return proxy end
package.preload["web.content_helper"] = function()
    return {convertResultToObject = function() 
        local rows = {}
        for i = 1, count do rows[i] = {enable = i == 1 and "1" or "0", name = "ftp"} end
        return rows
    end}
end
package.preload["web.ui_helper"] = function()
    return {
        createCardHeader = function() return "header" end,
        createHeader = function() return "header" end,
        createMessages = function() return "" end,
        createTable = function(columns, data, options)
            assert(options.basepath == (modern and "uci.firewall_helpers.helper." or "uci.firewall.helper.@."))
            assert(columns[2].name == (modern and "name" or "helper"))
            assert(columns[3].name == (modern and "port" or "dest_port"))
            assert(columns[1].name == "enable")
            return "table"
        end,
        createFooter = function() return "footer" end,
    }
end
package.preload["web.uimessage_helper"] = function() return {popMessages = function() return {} end} end
package.preload["web.post_helper"] = function()
    return {getRandomKey = function() return "key" end,
            handleTableQuery = function(columns, options)
                assert(options.basepath == (modern and "uci.firewall_helpers.helper." or "uci.firewall.helper.@."))
                return {{"1", "ftp", "21", "tcp"}}, {}
            end}
end
assert(loadfile(path))()
local html = table.concat(output)
if path:find("/cards/", 1, true) then
    if count == 0 then assert(html:find("No NAT Helpers found", 1, true))
    else assert(html:find("Enabled Helper", 1, true)) end
else assert(html:find("table", 1, true)) end
'''
        result = subprocess.run(
            [LUA, "-", str(path), str(modern).lower(), str(helpers)],
            input=script, text=True, capture_output=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_old_and_new_schemas(self):
        for modern in (False, True):
            with self.subTest(modern=modern):
                self.run_page(CARD, modern, 2)
                self.run_page(MODAL, modern, 2)
                self.run_page(CARD, modern, 0)


if __name__ == "__main__":
    unittest.main()
