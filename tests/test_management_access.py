"""Exercise WebUI rule migration and management-tab access together."""
import re
import shutil
import subprocess
import unittest
from pathlib import Path


GUI = Path(__file__).resolve().parents[1] / "decompressed/gui_file"
LUA = shutil.which("lua")


class ManagementAccessTests(unittest.TestCase):
    def test_fresh_configuration_authorizes_both_management_pages(self):
        source = (GUI / "tmp/web_unlock").read_text()
        sections = dict(re.findall(
            r"config \w+ '([^']+)'\n(.*?)(?=\nconfig |\Z)", source, re.S))
        for name, page in (("systeminitmodal", "system-init-modal.lp"),
                           ("systemcronmodal", "system-cron-modal.lp")):
            with self.subTest(page=page):
                self.assertEqual(sections["ruleset_main"].count(f"list rules '{name}'"), 1)
                rule = sections[name]
                self.assertIn(f"option target '/modals/{page}'", rule)
                self.assertEqual(re.findall(r"list roles '([^']+)'", rule),
                                 ["admin", "engineer"])
                self.assertTrue((GUI / "www/docroot/modals" / page).is_file())

    @unittest.skipUnless(LUA, "Lua interpreter required")
    def test_migration_repairs_existing_rules_and_preserves_tab_access(self):
        result = subprocess.run([LUA, "-", str(GUI)], input=r'''
local root = arg[1]
local config, commits = {}, 0
local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = copy(item) end
    return result
end
local saved
local cursor = {}
function cursor:foreach(package, kind, callback)
    assert(package == "web")
    for name, section in pairs(config) do
        if section[".type"] == kind then
            local value = copy(section)
            value[".name"] = name
            callback(value)
        end
    end
end
function cursor:get(package, name, option)
    assert(package == "web")
    local section = config[name]
    return section and section[option or ".type"]
end
function cursor:set(package, name, option, value)
    assert(package == "web")
    config[name] = config[name] or {}
    if value == nil then config[name][".type"] = option
    else config[name][option] = copy(value) end
    return true
end
function cursor:commit(package)
    assert(package == "web")
    saved, commits = copy(config), commits + 1
    return true
end
package.preload.uci = function() return {cursor = function() return cursor end} end
local function migrate()
    dofile(root .. "/usr/share/transformer/scripts/unlock_and_refresh_web_config.lua")
end
config.ruleset_main = {[".type"] = "ruleset", rules = {"existing"}}
config.existing = {[".type"] = "rule", target = "/existing", roles = {"admin", "engineer"}}
config.usr_admin = {[".type"] = "user", role = "engineer"}
migrate()
local baseline = copy(saved)
local rules = {
    systeminitmodal = "/modals/system-init-modal.lp",
    systemcronmodal = "/modals/system-cron-modal.lp",
    commandlogreadmodal = "/modals/command-log-read-modal.lp",
    ajaxcommandlogread = "/ajax/commandlogread.lua",
}
for _, failure in ipairs({"missing_section", "wrong_target", "wrong_type", "missing_roles", "scalar_roles", "unlisted"}) do
    config = copy(baseline)
    for name in pairs(rules) do
        if failure == "missing_section" then config[name] = nil
        elseif failure == "wrong_target" then config[name].target = "/wrong"
        elseif failure == "wrong_type" then config[name][".type"] = "card"
        elseif failure == "missing_roles" then config[name].roles = nil
        elseif failure == "scalar_roles" then config[name].roles = "engineer"
        elseif failure == "unlisted" then
            for index = #config.ruleset_main.rules, 1, -1 do
                if config.ruleset_main.rules[index] == name then
                    table.remove(config.ruleset_main.rules, index)
                end
            end
        end
    end
    local before = commits
    migrate()
    assert(commits > before, failure .. ": repair was not committed")
    config = copy(saved) -- Model a fresh process reading persistent config.
    for name, target in pairs(rules) do
        assert(config[name][".type"] == "rule", failure)
        assert(config[name].target == target, failure)
        local roles = {}
        for _, role in ipairs(config[name].roles) do roles[role] = true end
        assert(roles.admin and roles.engineer and not roles.guest, failure)
        local count = 0
        for _, rule in ipairs(config.ruleset_main.rules) do
            if rule == name then count = count + 1 end
        end
        assert(count == 1, failure .. ": duplicate or missing ruleset entry")
    end
    assert(config.existing.target == "/existing", failure)
    migrate()
    for name in pairs(rules) do
        local count = 0
        for _, rule in ipairs(config.ruleset_main.rules) do
            if rule == name then count = count + 1 end
        end
        assert(count == 1, failure .. ": repeat migration duplicated a rule")
    end
end
-- Older configurations can store a single rule as an option, not a list.
for _, value in ipairs({false, "existing"}) do
    config = copy(baseline)
    config.ruleset_main.rules = value or nil
    migrate()
    assert(saved.ruleset_main.rules)
    if value then assert(saved.ruleset_main.rules[1] == "existing") end
end
-- Exercise the real tab helper with the resulting access rules.
local role, tabs = "engineer"
local function hasAccess(_, target)
    for _, name in ipairs(saved.ruleset_main.rules) do
        local rule = saved[name]
        if rule and rule.target == target then
            for _, allowed in ipairs(rule.roles) do
                if allowed == role then return true end
            end
        end
    end
    return false
end
package.preload["web.ui_helper"] = function()
    return {createModalTabs = function(value) tabs = value; return "" end}
end
package.path = root .. "/www/lua/?.lua;" .. package.path
ngx = {var = {uri = ""}, ctx = {session = {hasAccess = hasAccess}}, print = function() end}
gettext = {textdomain = function() end}
T = function(value) return value end
for _, current in ipairs({"admin", "engineer", "guest"}) do
    role = current
    dofile(root .. "/www/snippets/tabs-management.lp")
    local found = {}
    for _, tab in ipairs(tabs) do found[tab.target] = true end
    for _, name in ipairs({"systeminitmodal", "systemcronmodal"}) do
        assert(not not found[rules[name]] == (role ~= "guest"), role)
    end
    for _, target in pairs(rules) do
        assert(hasAccess(nil, target) == (role ~= "guest"), role .. ": " .. target)
    end
end
''', text=True, capture_output=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
