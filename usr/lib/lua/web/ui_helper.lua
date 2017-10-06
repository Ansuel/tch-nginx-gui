-- NG-78956; NG-91245
--NG-96253 GPON-Diagnostics/Network needs to be lifted to TI specific functionalities
--NG-94758 GUI: Mobile card and modal are not completely translated
--NG-102545 GUI broadband is showing SFP Broadband GUI page when Ethernet 4 is connected
local require, pairs, ipairs, type, tonumber, getfenv = require, pairs, ipairs, type, tonumber, getfenv
local format, find, gsub, gmatch = string.format, string.find, string.gsub, string.gmatch
local huge = math.huge
local concat, sort, tostring = table.concat, table.sort, tostring
local istainted = string.istainted
local ngx = ngx
local untaint_mt = require("web.taint").untaint_mt
local html_escape = require("web.web").html_escape
local LedValuetoString  = {
    ["1"] = " green",
    ["2"] = " orange",
    ["3"] = " yellow",
    ["4"] = " red",
    ["true"] = " green",
}
setmetatable(LedValuetoString,untaint_mt)
-- Translation initialization. Every function relying on translation MUST call setlanguage to ensure the current
-- language is correctly set (it will fetch the language set by web.web and use it)
-- We create a dedicated context for the web framework (since we cannot easily access the context of the current page)
local intl = require("web.intl")
local function log_gettext_error(msg)
    ngx.log(ngx.NOTICE, msg)
end
local gettext = intl.load_gettext(log_gettext_error)
local T = gettext.gettext
local N = gettext.ngettext

local function setlanguage()
    gettext.language(ngx.header['Content-Language'])
end

gettext.textdomain('web-framework-tch')

--- ui_helper module
--  @module ui_helper
--  @usage local ui_helper = require('web.ui_helper')
--  @usage require('web.ui_helper')
local M = {}

-- Assumption: string tainting is in effect so we do not do additional parsing


--- Merges the two dictionaries by setting toadd as the index of base in its metatable
--  The only exception is the class property that will be concatenated + a few specific
--  behaviors to ensure expected results with bootstrap
--  @param #table base the main values to use
--  @param #table toadd the default values to use in case base does not contain the key
--  @return #table dictionary (ref to base)
local function mergeAttributes(base, toadd)
    if base == nil then
        base = {}
    end
    if toadd == nil then
        return base
    end

    for k,v in pairs(toadd) do
        if base[k] == nil then
            base[k] = {}
        end
        local b = base[k]

        if type(v) == "table" then
            -- Check for 'readonly' or 'disabled' attribute, which could be a security risk.
            -- Print a log message if we find it, unless explicitly disabled because they
            -- know what they're doing...
            if (v.readonly or v.disabled) and not v.no_warnlog then
                ngx.log(ngx.WARN, "'readonly' or 'disabled' attributes can be easily removed client side, making fields editable. ",
                                  "Use labels or make sure your code does not process POST data containing rogue values for such fields! ",
                                  "E.g. for handleTableQuery() use the 'readonly' property on your columns or use a validation function.")
            end
            v.no_warnlog = nil
            for k2,v2 in pairs(v) do
                if nil == b[k2] then
                    b[k2] = v2
                else
                    -- we only concatenate for the class attribute, for the rest we overwrite
                    -- if the toadd dictionary has a class entry, then it must have priority
                    -- this means that we must remove the entries in the base dictionary
                    -- that can conflict (span%d or table-%a+)
                    if k2 == "class" then
                        local baseclasstext = b[k2]
                        if find(v2, "span") ~= nil then
                            baseclasstext = gsub(baseclasstext, "span%d+", "")
                        end
                        if find(v2, "table-") ~= nil then
                            baseclasstext = gsub(baseclasstext, "table%-%a+","")
                        end
                        if find(v2, "help-block") ~= nil then
                            baseclasstext = gsub(baseclasstext, "help-inline","")
                        end
                        if find(v2, "alert-") ~= nil then
                            baseclasstext = gsub(baseclasstext, "alert%-%a+","")
                        end
                        if find(v2, "icon-") ~= nil then
                            baseclasstext = gsub(baseclasstext, "icon%-%a+","")
                        end
                        b[k2] = baseclasstext .. " " .. v2
                    else
                        b[k2] = v2
                    end
                end
            end
        end
    end
    return base
end

--- This function takes a dictionnary of k,v (v are all assumed to be strings)
-- It will correctly escape
-- @param #table attributes
-- @return #string string built from attributes
local function createAttributesString(attributes)
    local attr = {}

    for k,v in pairs(attributes) do
        attr[#attr + 1] = format('%s="%s"', k, html_escape(v))
    end
    return concat(attr, " ")
end

--- createAlertBlock
-- @function [parent=#ui_helper] createAlertBlock
-- @param #string value
-- @param #table attributes
-- @return #string for ngx.print
function M.createAlertBlock(value, attributes)
    local defaults = {
        alert = {
            class = "alert alert-error"
        },
    }
    mergeAttributes(defaults, attributes)
    local alert = createAttributesString(defaults["alert"])

    -- If there was a global error, display it
    local content = {}
    local text = value
    if text ~= nil then
        if type(text) ~= "table" then
            text = { text }
        end
        for _,v in ipairs(text) do
            content[#content+1] = format('<div %s>%s</div>', alert, v)
        end
    end
    return content
end

--- createHelpText
-- @function [parent=#ui_helper] createHelpText
-- @param #string value
-- @param #table attributes
-- @return #string for display by ngx.print
function M.createHelpText(value, attributes)
    local defaults = {
        help = {
            class = "help-inline"
        },
    }
    mergeAttributes(defaults, attributes)
    local help = createAttributesString(defaults["help"])

    local content = {}
    local text = value
    if text ~= nil then
        if type(text) ~= "table" then
            text = { text }
        end
        for _,v in ipairs(text) do
            content[#content+1] = format("<span %s>%s</span>", help, v)
        end
    end
    return content

end

---
-- Will convert a table of key/string to its representing JSON string
-- it will ensure that there is no non escaped " in the name or value
-- WARNING: it won't accept tainted strings (concat does not like them)
-- @param #table table
-- @return #string
local function convertKVToJson(table)
    local entries = {}
    for k,v in pairs(table) do
        entries[#entries+1] = '"' .. k:gsub('"', '\"') .. '": "' .. v:gsub('"', '\"') .. '"'
    end
    return '{' .. concat(entries, ',') .. '}'
end

--- createSimpleInputHidden
-- Template
--		<input name="{Name}" class="" type="hidden" value="{Value}">
-- @function [parent=#ui_helper] createSimpleInputHidden
-- @param #string name
-- @param #string value
-- @param #table attributes
-- @param #string helpmsg
-- @return #table array for ngx.print
function  M.createSimpleInputHidden(name, value, attributes, helpmsg)
    local defaults = {
        input = {
            class = "",
            type = "hidden",
            name = name,
            value = value,
        },
    }
    mergeAttributes(defaults, attributes)

    local input = createAttributesString(defaults["input"])

    local html = {
        format("<input %s>", input),
        M.createHelpText(helpmsg,attributes)
    }
    return html
end

--- createSimpleInputText
-- Template
--		<input name="{Name}" class="span3 edit-input" type="text" value="{Value}">
--	 	<span class="help-inline"><strong>Alert Title ! </strong> Alert details and explanations</span>
-- @function [parent=#ui_helper] createSimpleInputText
-- @param #string name
-- @param #string value
-- @param #table attributes
-- @param #string helpmsg
-- @return #table array for ngx.print
function  M.createSimpleInputText(name, value, attributes, helpmsg)
    local defaults = {
        input = {
            class = "edit-input span3",
            type = "text",
            name = name,
            value = value,
            id = name,
        },
        help = {
            class = "help-inline"
        },
    }
    mergeAttributes(defaults, attributes)

    if type(attributes) == "table" and type(attributes["autocomplete"]) == "table" then
        defaults.input["data-values"] = convertKVToJson(attributes["autocomplete"])
        defaults.input["autocomplete"] = "off"
        defaults.input["class"] = defaults.input["class"] .. " typeahead"
    end

    local input = createAttributesString(defaults["input"])
    local help = createAttributesString(defaults["help"])

    local html = {
        format("<input %s>", input),
        M.createHelpText(helpmsg,attributes)
    }
    return html
end

--- createInputText
-- Template
-- <div class="control-group">
--	<label class="control-label">{Description}</label>
--	<div class="controls">
--		<input name="{Name}" class="span3 edit-input" type="text" value="{Value}">
--	    <span class="help-inline"><strong>Alert Title ! </strong> Alert details and explainations</span>
--	</div>
-- </div>
-- @function [parent=#ui_helper] createInputText
-- @param #string desc
-- @param #string name
-- @param #string value
-- @param #table attributes
-- @param #string helpmsg
-- @return #table array for ngx.print
function M.createInputText(desc, name, value, attributes, helpmsg)
    local defaults = {
        group = {
            class="control-group"
        },
        label = {
            class="control-label"
        },
        controls = {
            class="controls"
        },
    }

    if helpmsg ~= nil then
        defaults.group.class = defaults.group.class .. " error"
    end

    mergeAttributes(defaults, attributes)
    local group = createAttributesString(defaults["group"])
    local label = createAttributesString(defaults["label"])
    local controls = createAttributesString(defaults["controls"])

    local content = {
        format("<div %s><label %s>%s</label><div %s>", group, label, desc, controls),
        M.createSimpleInputText(name, value, attributes, helpmsg),
        "</div></div>"
    }
    return content
end

--- createSimpleInputPassword
-- Template
--      <input name="{Name}" class="span3 edit-input" type="text" value="{Value}">
--      <span class="help-inline"><strong>Alert Title ! </strong> Alert details and explanations</span>
-- @function [parent=#ui_helper] createSimpleInputPassword
-- @param #string name
-- @param #string value
-- @param #table attributes
-- @param #string helpmsg
-- @return #table array for ngx.print
function  M.createSimpleInputPassword(name, value, attributes, helpmsg)
    local defaults = {
        input = {
            class = "edit-input span3",
            type = "password",
            autocomplete = "off",
            name = name,
            value = "",
	    id = name,
        },
        help = {
            class = "help-inline"
        },
    }
    if (type(value) == "string" or istainted(value)) and #value > 0 then
        defaults.input.value = "********" -- if there is a password, we set it to a dummy value
    end

    mergeAttributes(defaults, attributes)
    local input = createAttributesString(defaults["input"])
    local help = createAttributesString(defaults["help"])

    local html = {
        format("<input %s>", input),
        M.createHelpText(helpmsg,attributes)
    }
    return html
end

--- createInputPassword
-- Template
-- <div class="control-group">
--  <label class="control-label">{Description}</label>
--  <div class="controls">
--      <input name="{Name}" class="span3 edit-input" type="password" value="">
--      <span class="help-inline"><strong>Alert Title ! </strong> Alert details and explainations</span>
--  </div>
-- </div>
-- @function [parent=#ui_helper] createInputPassword
-- @param #string desc
-- @param #string name
-- @param #string value
-- @param #table attributes
-- @param #string helpmsg
-- @return #table array for ngx.print
function M.createInputPassword(desc, name, value, attributes, helpmsg)
    local defaults = {
        group = {
            class="control-group"
        },
        label = {
            class="control-label"
        },
        controls = {
            class="controls"
        },
    }

    if helpmsg ~= nil then
        defaults.group.class = defaults.group.class .. " error"
    end

    mergeAttributes(defaults, attributes)
    local group = createAttributesString(defaults["group"])
    local label = createAttributesString(defaults["label"])
    local controls = createAttributesString(defaults["controls"])

    local content = {
        format("<div %s><label %s>%s</label><div %s>", group, label, desc, controls),
        M.createSimpleInputPassword(name, value, attributes, helpmsg),
        "</div></div>"
    }
    return content
end

--- createSimpleInputCheckbox
-- Template
--              if suffixname == true
--              <input name="{Name}" class="" type="checkbox" value="{Value}">  "{Name}"</input><br\>
--              else
--              <input name="{Name}" class="" type="checkbox" value="{Value}">
-- @function [parent=#ui_helper] createSimpleInputCheckbox
-- @param #string name
-- @param #string value
-- @param #table attributes
-- @param #boolean suffixname
-- @return #string string for ngx.print
function  M.createSimpleInputCheckbox(name, value, attributes, suffixname)
    local defaults = {
        input = {
            class = "",
            type = "checkbox",
            name = name,
            value = tostring(value),
        },
    }
    mergeAttributes(defaults, attributes)
    local input = createAttributesString(defaults["input"])
    local checked = (value == "1" or value == true) and " checked" or ""
    if suffixname then
        return format("<input %s%s>  %s</input><br\> ", input, checked, name)
    end
    return format("<input %s%s>", input, checked)
end


--- createInputCheckbox
-- Template
-- <div class="control-group">
--      <label class="control-label">{Description}</label>
--      <div class="controls">
--              <input name="{Name}" class="" type="checkbox" value="{Value}">
--      </div>
-- </div>
-- @function [parent=#ui_helper] createInputCheckbox
-- @param #string desc
-- @param #string name
-- @param #string value
-- @param #table attributes
-- @return #table array for ngx.print
function M.createInputCheckbox(desc, name, value, attributes)
    local defaults = {
        group = {
            class="control-group"
        },
        label = {
            class="control-label"
        },
        controls = {
            class="controls"
        },
    }
    mergeAttributes(defaults, attributes)
    local group = createAttributesString(defaults["group"])
    local label = createAttributesString(defaults["label"])
    local controls = createAttributesString(defaults["controls"])

    local content = {
        format("<div %s><label %s>%s</label><div %s>", group, label, desc, controls),
        M.createSimpleInputCheckbox(name, value, attributes),
        "</div></div>"
    }
    return content
end

--- createSimpleCheckboxSwitch
-- Template
--              <input name="{Name}" class="" type="checkbox" value="{Value}">  "{Name}"</input><br\>
--              else
--              <input name="{Name}" class="" type="checkbox" value="{Value}">
-- @function [parent=#ui_helper] createSimpleCheckboxSwitch
-- @param #string name
-- @param #string value
-- @param #table attributes
-- @return #string string for ngx.print
function  M.createSimpleCheckboxSwitch(name, value, attributes)
    local content = {}
    local defaults = {
        checkbox = {
            class = "checkbox"
        },
        input = {
            type = "checkbox",
            name = name,
	    id = name
        }
    }
    mergeAttributes(defaults, attributes)
    local label = createAttributesString(defaults["checkbox"])
    local input = createAttributesString(defaults["input"])

    local checked = (value == "1" or value == true) and " checked" or ""
    -- We'll add an empty value in every case to make sure the browser sends back an element for the given name
    -- otherwise if none of the checkboxes are selected, then nothing is sent back for that name
    -- the validation function will have the responsibility to remove that dummy value
    -- we choose an empty string value (since it sould not be used
    content[#content + 1] = format('<label class="hide checkbox"><input type="checkbox" name="%s" value="_DUMMY_" checked></label>', name)
    content[#content + 1] = format('<label %s>', label)
    content[#content + 1] = format('<input %s value="%s" %s> %s</label>', input, "_TRUE_", checked, "")
    return content
end

--- createCheckboxSwitch
-- Template
-- <div class="control-group">
--      <label class="control-label">{Description}</label>
--      <div class="controls">
--              <input name="{Name}" class="" type="checkbox" value="{Value}">
--      </div>
-- </div>
-- @function [parent=#ui_helper] createInputCheckbox
-- @param #string desc
-- @param #string name
-- @param #string value
-- @param #table attributes
-- @return #table array for ngx.print
function M.createCheckboxSwitch(desc, name, value, attributes)
    local defaults = {
        group = {
            class="control-group"
        },
        label = {
            class="control-label"
        },
        controls = {
            class="controls"
        },
    }
    mergeAttributes(defaults, attributes)
    local group = createAttributesString(defaults["group"])
    local label = createAttributesString(defaults["label"])
    local controls = createAttributesString(defaults["controls"])

    local content = {
        format("<div %s><label %s>%s</label><div %s>", group, label, desc, controls),
        M.createSimpleCheckboxSwitch(name, format("%s",value), attributes),
        "</div></div>"
    }
    return content
end

--- createSimpleChecboxGroup
-- Template
--           <label class="checkbox">
--           <input name="{Name}" type="checkbox" value="{Value}" checked>  {Name}
--           </label>
--           ...
-- @function [parent=#ui_helper] createSimpleCheckboxGroup
function M.createSimpleCheckboxGroup(name, values, checked, attributes)
    local content = {}
    local defaults = {
        checkbox = {
            class = "checkbox"
        },
        input = {
            type = "checkbox",
            name = name
        }
    }
    mergeAttributes(defaults, attributes)
    local label = createAttributesString(defaults["checkbox"])
    local input = createAttributesString(defaults["input"])

    local check = {}
    if type(checked) == "table" then
       for i,v in ipairs(checked) do
           check[v] = true
       end
    end

    -- We'll add an empty value in every case to make sure the browser sends back an element for the given name
    -- otherwise if none of the checkboxes are selected, then nothing is sent back for that name
    -- the validation function will have the responsibility to remove that dummy value
    -- we choose an empty string value (since it sould not be used
    content[#content + 1] = format('<label class="hide checkbox"><input type="checkbox" name="%s" value="" checked></label>', name)

    for i,v in ipairs(values) do
        local checked = ""
        content[#content + 1] = format('<label %s>', label)
        if check[v[1]] then
            checked = "checked"
        end
        content[#content + 1] = format('<input %s value="%s" %s> %s</label>', input, v[1], checked, v[2])
    end
    return content
end

--- createCheckboxGroup
-- Template
-- <div class="control-group">
--      <label class="control-label">{Description}</label>
--      <div class="controls">
--           <label class="checkbox">
--           <input name="{Name}" type="checkbox" value="{Value}" checked>  {Name}
--           </label>
--           ...
--           <span class="help-inline"><strong>Alert Title ! </strong> Alert details and explainations</span>
--      </div>
-- </div>
-- @function [parent=#ui_helper] createCheckboxGroup
-- @param #string desc
-- @param #table namevaluemap
-- @param #table attributes
-- @return #table array for ngx.print
function M.createCheckboxGroup(desc, name, values, checked, attributes, helpmsg)
    local defaults = {
        group = {
            class="control-group"
        },
        label = {
            class="control-label"
        },
        controls = {
            class="controls"
        },
    }
    mergeAttributes(defaults, attributes)
    local group = createAttributesString(defaults["group"])
    local label = createAttributesString(defaults["label"])
    local controls = createAttributesString(defaults["controls"])

    local content = {
        format("<div %s>", group)
    }
    content[#content + 1] = format("<label %s>%s</label><div %s>", label, desc, controls)

    content[#content + 1] = M.createSimpleCheckboxGroup(name, values, checked, attributes)
    content[#content + 1] = M.createAlertBlock(helpmsg,attributes)

    content[#content + 1] = "</div></div>"
    return content
end

---
--	Template
-- 			  <div class="control-group">
--			   	 <label class="control-label">{Description}</label>
--			   	 <div class="controls">
--				   	<span class="span2 simple-desc">{Value}</span>
--	 		  		<span class="help-inline"><strong>Alert Title ! </strong> Alert details and explainations</span>
--			   	 </div>
--			  </div>
-- @function [parent=#ui_helper] createLabel
-- @param #string desc: text used for the label description
-- @param #string value: text used for the label values
-- @param #table attributes: maps additional attributes to apply
-- @param #string helpmsg
-- @return #string
function M.createLabel(desc, value, attributes, helpmsg)
    local defaults = {
        group = {
            class="control-group"
        },
        label = {
            class="control-label"
        },
        controls = {
            class="controls"
        },
        span = {
            class = "span2 simple-desc",
	    id = desc
        },
        help = {
            class = "help-inline"
        }
    }

    if helpmsg ~= nil then
        defaults.group.class = defaults.group.class .. " error"
    end

    mergeAttributes(defaults, attributes)
    local group = createAttributesString(defaults["group"])
    local label = createAttributesString(defaults["label"])
    local controls = createAttributesString(defaults["controls"])
    local span = createAttributesString(defaults["span"])
    local help = createAttributesString(defaults["help"])

    local html = {
        format("<div %s><label %s>%s</label><div %s><span %s>%s</span>",group, label, desc, controls, span, value),
        M.createHelpText(helpmsg,attributes),
        "</div></div>"
    }
    return html
end

---
-- Template
--			 			<div class="switch {switchOn} pull-left">
--			 				<div class="switcher {switcherOn}"></div>
--				 			<input type="hidden" name="{name}" value="{value}">
--		 				</div>
--	 		  		    <span class="help-inline"><strong>Alert Title ! </strong> Alert details and explainations</span>
-- @function [parent=#ui_helper] createSimpleSwitch
-- @param #string name
-- @param #string value
-- @param #table attributes
-- @param #string helpmsg
-- @return #table array for ngx.print
function M.createSimpleSwitch(name, value, attributes, helpmsg)
    setlanguage()
    local defaults = {
        switch = {
            class = "switch"
        },
        switcher = {
            class = "switcher"
        },
        input = {
            type = "hidden",
            name = name,
            value = value,
	    id = name
        },
        help = {
            class = "help-inline",
        },
        values = {
            on = "1",
            off = "0"
        }
    }

    mergeAttributes(defaults, attributes)
    local valOn = defaults["values"]["on"]
    local valOff = defaults["values"]["off"]

    if value == valOn then
        defaults["switch"]["class"] = defaults["switch"]["class"] .. " switchOn"
        defaults["switcher"]["class"] = defaults["switcher"]["class"] .. " switcherOn"
    else
        defaults["input"]["value"] = valOff
    end

    local switch = createAttributesString(defaults["switch"])
    local switcher = createAttributesString(defaults["switcher"])
    local input = createAttributesString(defaults["input"])
    local help = createAttributesString(defaults["help"])

    local html = {
        format('<div %s><div %s textON="%s" textOFF="%s" valOn="%s" valOff="%s"></div><input %s></div>', switch, switcher, T"ON", T"OFF", valOn, valOff, input),
        M.createHelpText(helpmsg,attributes)
    }
    return html
end

---
-- Template
--				<div class="control-group">
--		 			<label class="control-label">Enabled</label>
--		 			<div class="controls">
--			 			<div id="personal-wireless-switch" class="switch {switchOn} pull-left">
--			 				<div class="switcher {switcherOn}"></div>
--				 			<input type="hidden" name="{name}" value="{value}">
--		 				</div>
--	 		  			<span class="help-inline"><strong>Alert Title ! </strong> Alert details and explainations</span>
--					</div>
--				</div>
-- @function [parent=#ui_helper] createSwitch
-- @param #string desc
-- @param #string name
-- @param #string value
-- @param #table attributes
-- @param #string helpmsg
-- @return #table
function M.createSwitch(desc, name, value, attributes, helpmsg)
    local defaults = {
        group = {
            class = "control-group"
        },
        label = {
            class = "control-label"
        },
        controls = {
            class = "controls"
        },
    }

    if helpmsg ~= nil then
        defaults.group.class = defaults.group.class .. " error"
    end

    mergeAttributes(defaults, attributes)
    local group = createAttributesString(defaults["group"])
    local label = createAttributesString(defaults["label"])
    local controls = createAttributesString(defaults["controls"])

    local content = {
        format("<div %s><label %s>%s</label><div %s>", group, label, desc, controls),
        M.createSimpleSwitch(name, value, attributes, helpmsg),
        "</div></div>"
    }
    return content
end

---
-- Template
--	 		  		<select name="{Name}" class="span3">
--						<option value="{value[i]" {selected} >{text[i]}</option>
--	 		  		</select>
--	 		  		<span class="help-inline"><strong>Alert Title ! </strong> Alert details and explainations</span>
--
-- @function [parent=#ui_helper] createSimpleInputSelect
-- @param #string name
-- @param #table values
-- @param #string current
-- @param #table attributes
-- @param #string helpmsg
-- @return #table array for ngx.print
function M.createSimpleInputSelect(name, values, current, attributes, helpmsg)
    local defaults = {
        select = {
            class = "span3",
            name = name,
	    id = name
        },
        help = {
            class = "help-inline",
        },
    }
    mergeAttributes(defaults, attributes)
    local select = createAttributesString(defaults["select"])
    local help = createAttributesString(defaults["help"])

    local html = {
        format("<select %s>", select)
    }

    for i,v in ipairs(values) do
        local selected = ""
        if current == v[1] then
            selected = 'selected="selected"'
        end
        html[#html + 1] = format("<option value=%q %s>%s</option>", v[1], selected, v[2])
    end

    html[#html + 1] = "</select>"
    html[#html + 1] = M.createHelpText(helpmsg,attributes)
    return html
end

---
-- Template
--	 		  <div class="control-group">
--	 		   	<label class="control-label">{Description}</label>
--	 		   	<div class="controls">
--	 		  		<select name="{Name}" class="span3">
--						<option value="{value[i]" {selected} >{text[i]}</option>
--	 		  		</select>
--	 		  		<span class="help-inline"><strong>Alert Title ! </strong> Alert details and explainations</span>
--	 		   	</div>
--	 		  </div>
-- @function [parent=#ui_helper] createInputSelect
-- @param #string desc
-- @param #string name
-- @param #table values
-- @param #string current
-- @param #table attributes
-- @param #string helpmsg
-- @return #table
function M.createInputSelect(desc, name, values, current, attributes, helpmsg)
    local defaults = {
        group = {
            class="control-group"
        },
        label = {
            class="control-label"
        },
        controls = {
            class="controls"
        },
    }

    if helpmsg ~= nil then
        defaults.group.class = defaults.group.class .. " error"
    end

    mergeAttributes(defaults, attributes)
    local group = createAttributesString(defaults["group"])
    local label = createAttributesString(defaults["label"])
    local controls = createAttributesString(defaults["controls"])

    local html = {
        format("<div %s><label %s>%s</label><div %s>",group, label, desc, controls),
        M.createSimpleInputSelect(name, values, current, attributes, helpmsg),
        "</div></div>"
    }
    return html
end

---
-- Template
--              <label class="radio">
--                  <input type="radio" name="{Name} value="{value[i]}" {selected} >{text[i]}
--              </label>
--
-- @function [parent=#ui_helper] createSimpleInputRadio
-- @param #string name
-- @param #table values
-- @param #string current
-- @param #table attributes
-- @return #table array for ngx.print
function M.createSimpleInputRadio(name, value, current, attributes)
    local defaults = {
        radio = {
            class = "radio",
        },
        input = {
            name = name,
            value = value[1]
        },
    }

    if current == value[1] then
        defaults.input["checked"]="checked"
    end

    mergeAttributes(defaults, attributes)
    local input = createAttributesString(defaults["input"])
    local radio = createAttributesString(defaults["radio"])

    local html = {
        format("<label %s>", radio),
        format("<input type='radio' %s />%s", input, value[2]),
        "</label>",
    }
    return html
end

---
-- Template
--            <div class="control-group">
--              <label class="control-label">{Description}</label>
--              <div class="controls">
--              <label class="radio">
--                  <input type="radio" name="{Name} value="{value[i]}" {selected} >{text[i]}
--              </label>
--              (...)
--              <span class="help-inline"><strong>Alert Title ! </strong> Alert details and explainations</span>
--            </div>
--            </div>
-- @function [parent=#ui_helper] createInputRadio
-- @param #string desc
-- @param #string name
-- @param #table values
-- @param #string current
-- @param #table attributes
-- @param #string helpmsg
-- @return #table
function M.createInputRadio(desc, name, values, current, attributes, helpmsg)
    local defaults = {
        group = {
            class="control-group"
        },
        label = {
            class="control-label"
        },
        controls = {
            class="controls"
        },
    }

    if helpmsg ~= nil then
        defaults.group.class = defaults.group.class .. " error"
    end

    mergeAttributes(defaults, attributes)
    local group = createAttributesString(defaults["group"])
    local label = createAttributesString(defaults["label"])
    local controls = createAttributesString(defaults["controls"])

    local html = {
        format("<div %s><label %s>%s</label><div %s>",group, label, desc, controls),
    }
    for i,v in ipairs(values) do
        html[#html+1] = M.createSimpleInputRadio(name, v, current, attributes)
    end
    html[#html + 1] = M.createHelpText(helpmsg,attributes)

    html[#html+1] = "</div></div>"

    return html
end

--- Create a button control without label
--  Template:
--      <div class="btn"><i class="{icon}"></i>  {label}</div>
-- @function [parent=#ui_helper] createSimpleButton
--    @param #string buttontext
--    @param #string icon
--    @param #table attributes
--    @return #string
function M.createSimpleButton(buttontext, icon, attributes)
    local defaults = {
        button = {
            class = "btn",
	    id = buttontext,
        },
        icon = {
            class = icon
        }
    }
    mergeAttributes(defaults, attributes)
    local button = createAttributesString(defaults["button"])
    local icon = createAttributesString(defaults["icon"])

    return format("<div %s><i %s></i>  %s</div>", button, icon, buttontext)
end

--- Create a button control
--  Template:
--  <div class="control-group">
--    <label class="control-label">{Description}</label>
--    <div class="controls">
--      <div class="btn"><i class="{icon}"></i>  {label}</div>
--    </div>
--  </div>
-- @function [parent=#ui_helper] createButton
--  @param #string desc
--  @param #string buttontext
--  @param #string icon
--  @param #table attributes
--  @return #table
function M.createButton(desc, buttontext, icon, attributes)
    local defaults = {
        group = {
            class="control-group"
        },
        label = {
            class="control-label"
        },
        controls = {
            class="controls"
        },
    }
    mergeAttributes(defaults, attributes)
    local group = createAttributesString(defaults["group"])
    local controls = createAttributesString(defaults["controls"])
    local label = createAttributesString(defaults["label"])

    local content = {
        format("<div %s><label %s>%s</label><div %s>", group, label, desc, controls),
        M.createSimpleButton(buttontext, icon, attributes),
        "</div></div>"
    }
    return content
end

--- Create a text input + button control
--  Template:
--  <div class="control-group">
--    <label class="control-label">{Description}</label>
--    <div class="controls">
--      <div class="btn"><i class="{icon}"></i>  {label}</div>
--    </div>
--  </div>
-- @function [parent=#ui_helper] createInputTextWithButton
--  @param #string desc
--  @param #string name
--  @param #boolean value
--  @param #string buttontext
--  @param #string icon
--  @param #table attributes
--  @param #table helpmsg
--  @return #table
function M.createInputTextWithButton(desc, name, value, buttontext, icon, attributes, helpmsg)
    local defaults = {
        group = {
            class="control-group"
        },
        label = {
            class="control-label"
        },
        controls = {
            class="controls"
        },
        help = {
            class = "help-inline"
        },
    }

    if helpmsg ~= nil then
        defaults.group.class = defaults.group.class .. " error"
    end

    mergeAttributes(defaults, attributes)
    local group = createAttributesString(defaults["group"])
    local label = createAttributesString(defaults["label"])
    local controls = createAttributesString(defaults["controls"])

    local content = {
        format("<div %s><label %s>%s</label><div %s>", group, label, desc, controls),
        M.createSimpleInputText(name, value, attributes),
        M.createSimpleButton(buttontext,icon,attributes),
        M.createHelpText(helpmsg,attributes),
        "</div></div>"
    }
    return content
end

--- Create the header of a table
--  Template
--              <thead>
--                <tr>
--                  <th>{header[1]}</th>
--                  <th>{header[2]}</th>
--                  <th>{header[3]}</th>
--                  <th>{header[4]}</th>
--                  (...)
--                </tr>
--              </thead>
--  @param #table columns
--  @param #boolean actionColumn
--  @return #table array for ngx.print
local function createTableHead(columns, actionColumn)
    local content = {
        "<thead><tr>"
    }
    for _,v in ipairs(columns) do
        content[#content + 1] = format("<th>%s</th>", v.header)
    end
    if actionColumn == true then
        -- add last column for actions
        content[#content + 1] = "<th></th>"
    end
    content[#content + 1] = "</tr></thead>"
    return content
end

---
-- Create the html to display inside a cell for a given column + value
-- @param #table column the column description
-- @param v the current value (string or table, depends on column type)
-- @return #table
local function createTableDataColumn(column, v)
    local content = {}
    local attrSwitch = {
        switch = {
            class = "switch disabled"
        },
    }

    if column.type == "select" then
        -- go through the values and insert the "text" that goes with the value
        local done = false
        for _,o in ipairs(column.values) do
            if o[1] == v then
                done = true
                content[#content + 1] = o[2]
            end
        end
        -- fallback in case we don't find the option in the list of values
        -- should not happen, but if it did, and we did nothing, would shift
        -- all the columns by 1
        if done == false then
            content[#content + 1] = v
        end
    elseif column.type == "switch" then
        content[#content + 1] = M.createSimpleSwitch(column.name, v, attrSwitch)
    elseif column.type == "checkboxswitch" then
        content[#content + 1] = M.createSimpleCheckboxSwitch(column.name, v, attrSwitch)
    elseif column.type == "light" then
        content[#content + 1] = M.createSimpleLight(v, "", {})
    elseif column.type == "checkboxgroup" then
        content[#content + 1] = M.createSimpleCheckboxGroup(column.name, column.values, v, { input = { disabled = "disabled", no_warnlog = true } })
    elseif column.type == "aggregate" then
        if type(column.synthesis) == "function" then
            content[#content + 1] = column.synthesis(v)
        end
    elseif column.type ~= "hidden" then
        content[#content + 1] = v
    end
    return content
end

---
-- @param #table v column description
-- @param #table data
-- @param #table helpmsg
-- @return #table
local function createTableDataEditColumn(v, data, helpmsg)
    local content = {}

    local attributes = {}
    if helpmsg then
        local baseattr = {
            class = "tooltip-on error",
            ["data-placement"] = "top",
            ["data-original-title"] = helpmsg,
        }
        attributes = {
            switch = baseattr,
            input = baseattr,
            select = baseattr,
        }
        content[#content + 1] = [[<div class="control-group error">]]
    else
        content[#content + 1] = [[<div class="control-group">]]
    end

    mergeAttributes(attributes, v.attr)

    if v.type == "text" then
        content[#content + 1] = M.createSimpleInputText(v.name, data or v.default or "", attributes)
    elseif v.type == "password" then
        content[#content + 1] = M.createSimpleInputPassword(v.name, data or v.default or "", attributes)
    elseif v.type == "select" then
        content[#content + 1] = M.createSimpleInputSelect(v.name, v.values, data or v.default or "", attributes)
    elseif v.type == "switch" then
        content[#content + 1] = M.createSimpleSwitch(v.name, data or v.default or true, attributes)
    elseif v.type == "checkboxswitch" then
        content[#content + 1] = M.createSimpleCheckboxSwitch(v.name, data or v.default or true, attributes)
    elseif v.type == "checkboxgroup" then
        if data == nil then
            data = {}
        end
        content[#content + 1] = M.createSimpleCheckboxGroup(v.name, v.values, data, attributes)
    elseif v.type == "hidden" then
        content[#content + 1] = M.createSimpleInputHidden(v.name, data or v.default or "", attributes)
    elseif v.type == "label" then
        content[#content + 1] = data
    end
    content[#content + 1] = "</div>"
    return content
end

---
-- @param #table v column description
-- @param #table data
-- @param #table helpmsg
-- @return #table
local function createTableDataEditAggregElem(v, data, helpmsg)
    local content = {}

    local attributes = {}

    mergeAttributes(attributes, v.attr)

    if v.type == "text" then
        content[#content + 1] = M.createInputText(v.header, v.name, data or v.default or "", attributes, helpmsg)
    elseif v.type == "password" then
        content[#content + 1] = M.createInputPassword(v.header, v.name, data or v.default or "", attributes, helpmsg)
    elseif v.type == "select" then
        content[#content + 1] = M.createInputSelect(v.header, v.name, v.values, data or v.default or "", attributes, helpmsg)
    elseif v.type == "switch" then
        content[#content + 1] = M.createSwitch(v.header, v.name, data or v.default or true, attributes, helpmsg)
    elseif v.type == "checkboxswitch" then
        content[#content + 1] = M.createCheckboxSwitch(v.header, v.name, data or v.default or true, attributes, helpmsg)
    elseif v.type == "checkboxgroup" then
        if data == nil then
            data = v.default or {}
        end
        content[#content + 1] = M.createCheckboxGroup(v.header, v.name, v.values, data, attributes, helpmsg)
    elseif v.type == "hidden" then
        content[#content + 1] = M.createSimpleInputHidden(v.name, data or v.default or "", attributes)
    end
    return content
end

--- Create a line of edit component to add a new element
--  @param #table columns
--  @param #table data array
--  @param #boolean add if true we're in add mode, if false, we're in edit mode
--  @param #table helpmsg
--  @return #table array for ngx.print
local function createTableDataEdit(columns, data, add, helpmsg)
    local attrAdd = {
        button = {
            class = "btn-mini btn-primary btn-table-add tooltip-on",
            ["data-placement"] = "top",
            ["data-original-title"] = T"Add",
        }
    }
    local attrModify = {
        button = {
            class = "btn-mini btn-primary btn-table-modify tooltip-on",
            ["data-placement"] = "top",
            ["data-original-title"] = T"Apply",
        }
    }
    local attrCancel = {
        button = {
            class = "btn-mini btn-danger btn-table-cancel tooltip-on",
            ["data-placement"] = "top",
            ["data-original-title"] = T"Cancel",
        }
    }

    if data == nil then
        data = {}
    end

    local numcolumns = #columns
    local content = { '<tr class="line-edit">' }
    local aggreg_lines = {}
    helpmsg = helpmsg or {}

    for i,v in pairs(columns) do
        content[#content + 1] = "<td>"
        if v.type == "aggregate" then
            aggreg_lines[#aggreg_lines + 1] = { legend = v.legend, columns = v.subcolumns, data = data[i] or v.default or {} }
        else
            if v.readonly then
                content[#content + 1] = createTableDataColumn(v,data[i])
            else
                content[#content + 1] = createTableDataEditColumn(v, data[i], helpmsg[v.name])
            end
        end
        content[#content + 1] = "</td>"
    end

    content[#content + 1] = "<td>"
    if add == true then
        content[#content + 1] = M.createSimpleButton("","icon-plus-sign", attrAdd)
        content[#content + 1] = " "
        content[#content + 1] = M.createSimpleButton("","icon-remove", attrCancel)
    elseif #aggreg_lines < 1 then
        content[#content + 1] = M.createSimpleButton("","icon-ok", attrModify)
        content[#content + 1] = " "
        content[#content + 1] = M.createSimpleButton("","icon-remove", attrCancel)
    end

    content[#content + 1] = "</td></tr>"

    for _,al in ipairs(aggreg_lines) do
        content[#content + 1] = "<tr class='additional-edit'>"
        content[#content + 1] = format('<td colspan="%d">', numcolumns)
        content[#content + 1] = format("<fieldset><legend>%s</legend>", al.legend)

        for i,v in pairs(al.columns) do
            content[#content + 1] = createTableDataEditAggregElem(v, al.data[i], helpmsg[v.name])
        end
        content[#content + 1] = "</fieldset>"
        content[#content + 1] = "</td><td></td>"
        content[#content + 1] = "</tr>"
    end
    if not add and #aggreg_lines > 0 then
       content[#content + 1] = format('<tr> <td class="btn-col-OK" colspan="%d">', numcolumns)
       content[#content + 1] = M.createSimpleButton("","icon-ok", attrModify)
       content[#content + 1] = " "
       content[#content + 1] = M.createSimpleButton("","icon-remove", attrCancel)
       content[#content + 1] = "</td></tr>"
    end
    return content
end

--- Create the table data
--                <tr>
--                  <td>{data[1][1]}</td>
--                  <td>{data[1][2]}</td>
--                  <td>{data[1][3]}</td>
--                  <td>{data[1][4]}</td>
--                  (...)
--                </tr>
--                (...)
--  @param #table columns
--  @param #table data array
--  @param #boolean canEdit
--  @param #boolean canDelete
--  @param #number editing
--  @param #table helpmsg
--  @param #table allowedindexes
--  @return #table
local function createTableData(columns, data, canEdit, canDelete, editing, helpmsg, allowedindexes)
    local content = {}
    local attrEdit = {
        button = {
            class = "btn-mini btn-table-edit tooltip-on",
            ["data-placement"] = "top",
            ["data-original-title"] = T"Edit",
        }
    }
    local attrDelete = {
        button = {
            class = "btn-mini btn-danger btn-table-delete tooltip-on",
            ["data-placement"] = "top",
            ["data-original-title"] = T"Delete",
        }
    }

    for i,l in ipairs(data) do
        if editing == i then
            -- If we're editing the current line
            content[#content + 1] = createTableDataEdit(columns, l, false, helpmsg)
        else
            -- If we're just displaying the current line
            content[#content + 1] = "<tr>"
            for j,v in ipairs(l) do
                content[#content + 1] = "<td>"
                content[#content + 1] = createTableDataColumn(columns[j], v)
                content[#content + 1] = "</td>"
            end
            -- Action column (will be empty if nothing allowed)
            -- Only display the action buttons if the user is not editing a line
	    local actionBtns = ""
            if canEdit == true and allowedindexes[i].canEdit then
                if editing ~= 0 then
                    attrEdit.button.class = attrEdit.button.class .. " disabled"
                end
                actionBtns = M.createSimpleButton("", "icon-edit", attrEdit)
            end
            content[#content + 1] = " "
            if canDelete == true and allowedindexes[i].canDelete then
                if editing ~= 0 then
                    attrDelete.button.class = attrDelete.button.class .. " disabled"
                end
                actionBtns = actionBtns .. M.createSimpleButton("", "icon-remove-sign icon-large", attrDelete)
            end
            -- Action column will not be created if no actions specified
            if actionBtns ~= "" then
                content[#content + 1] = format("<td>%s</td>", actionBtns)
            end
            content[#content + 1] = "</tr>"
        end
    end
    return content
end

--- Create the button at the bottom of the table
-- Template
-- <div class="btn-group">
--  <div class="btn" tabindex="-1">Action</button>
--  <div class="btn dropdown-toggle" data-toggle="dropdown" tabindex="-1">
--    <span class="caret"></span>
--  </button>
--  <ul class="dropdown-menu">
--    <li><a href="#">Action</a></li>
--    <li><a href="#">Another action</a></li>
--    <li><a href="#">Something else here</a></li>
--    <li class="divider"></li>
--    <li><a href="#">Separated link</a></li>
--  </ul>
--</div>
-- @param #boolean canAdd should we display the button
-- @param #number editing which element are we editing (0 = none, -1 = new, other = index)
-- @param #string createMsg text to display on the button
local function createTableButton(canAdd, editing, createMsg, newList)
    local content = {}
    local buttonAttr = {
        button = {
            class = "btn-table-new"
        }
    }
    local dropdownclass = "btn dropdown-toggle"

    if (canAdd == true) then
        if editing ~= 0 then
            buttonAttr.button.class = buttonAttr.button.class .. " disabled"
            dropdownclass = dropdownclass .. " disabled"
        end
        content[#content + 1] = '<center><div class="btn-group">'
        content[#content + 1] = M.createSimpleButton(createMsg,"icon-plus-sign", buttonAttr)
        if newList ~= nil then
            content[#content + 1] = format('<div class="%s" data-toggle="dropdown" tabindex="-1" ><span class="caret"></span></div>', dropdownclass)
            content[#content + 1] = '<ul class="dropdown-menu">'
            for i,v in ipairs(newList) do
                content[#content + 1] = format('<li><a href="#" class="btn-table-new-list" data-listid="%d" >%s</a></li>', i, v.text)
            end
            content[#content + 1] = '</ul>'
        end
        content[#content + 1] = "</div></center>"
    end
    return content
end

--- Create a table
-- Template
-- <table class="table table-striped">
--              <thead>
--                <tr>
--                  <th>{header[1]}</th>
--                  <th>{header[2]}</th>
--                  <th>{header[3]}</th>
--                  <th>{header[4]}</th>
--                  (...)
--                </tr>
--              </thead>
--              <tbody>
--                <tr>
--                  <td>{data[1][uciname[1])}</td>
--                  <td>{data[1][uciname[2])}</td>
--                  <td>{data[1][uciname[3])}</td>
--                  <td>{data[1][uciname[4])}</td>
--                  (...)
--                </tr>
--                (...)
--              </tbody>
--            </table>
-- @function [parent=#ui_helper] createTable
-- @param #table columns
-- @param #table data array
-- @param #table options
-- @param #table attributes
-- @param #table helpmsg
-- @return #table
function M.createTable(columns, data, options, attributes, helpmsg)
    setlanguage()
    local defaults = {
        group = {
            class="control-group"
        },
        table = {
            class="table table-striped",
            id= options and options.tableid or "youforgottheid",
            ["data-stateid"]= options and options.stateid,
        },
    }

    -- options and their default value
    -- do we allow to edit a table entry?
    local canEdit = options and not (options.canEdit == false)
    -- are we editing an entry and which line (-1 means new entry, 0 means not editing)
    local editing = options and tonumber(options.editing) or 0
    -- do we disallow delete if under a certain number of entries
    local minEntries = options and tonumber(options.minEntries) or 0
    -- do we disallow adding if above a certain number of entries
    local maxEntries = (options and options.maxEntries) or huge
    local createMsg = (options and options.createMsg) or T"Create new"

    local numEntries = #data
    -- can we add entries? need to be allowed and need to be under maximum number of entries
    local canAdd = options and not (options.canAdd == false) and (numEntries < maxEntries)
    -- can we delete entries? need to be allowed and need to be above minimum number of entries
    local canDelete = options and not (options.canDelete == false) and (numEntries > minEntries)
    local newList = options and options.newList

    local session = ngx.ctx.session
    local tablesessionindexes = options.tableid .. ".allowedindexes"

    mergeAttributes(defaults, attributes)
    local groupattr = createAttributesString(defaults["group"])
    local tableattr = createAttributesString(defaults["table"])

    local allowedIndexes = session:retrieve(tablesessionindexes) or {}
    local content = {
        -- If there was a global error, display it
        M.createAlertBlock(options.errmsg, attributes),
        format("<div %s><table %s>", groupattr, tableattr),
        -- headers
        createTableHead(columns, canEdit or canDelete),
        -- the data itself
        "<tbody>",
        createTableData(columns,data,canEdit,canDelete, editing, helpmsg, allowedIndexes)
    }
    -- if not editing another line and editing allowed, add a last line allowing to add a new entry
    if (canAdd == true) and (editing == -1) then
        content[#content + 1] = createTableDataEdit(columns,{}, true, helpmsg)
    end
    content[#content + 1] = "</tbody></table>"
    content[#content + 1] = createTableButton(canAdd, editing, createMsg, newList)
    content[#content + 1] = "</div>"
    return content
end

--- Template
--			 <span class="simple-desc">
--			  <div class="light green"></div>This is a status
--			 </span>
-- @function [parent=#ui_helper] createSimpleLight
-- @param #boolean value
-- @param #string desc
-- @param #table attributes
-- @return #string for ngx.print
function M.createSimpleLight(value, text, attributes)
    local defaults = {
        span = {
            class = "simple-desc",
        },
        light = {
            class = "light"
        }
    }

    if value ~= nil then
       defaults.light.class = defaults.light.class .. (LedValuetoString[value] or " off")
    end

    mergeAttributes(defaults, attributes)
    local span = createAttributesString(defaults["span"])
    local light = createAttributesString(defaults["light"])

    return format("<span %s><div %s></div>%s</span>", span, light, text)
end


--- Template
-- <div class="control-group">
--		   <label class="control-label">Broadband status</label>
--		   <div class="controls">
--			 <span class="simple-desc">
--			  <div class="light green"></div>This is a status
--			 </span>
--		   </div>
--		 </div>
-- @function [parent=#ui_helper] createLight
-- @param #string label
-- @param #boolean value
-- @param #string desc
-- @param #table attributes
function M.createLight(desc, value, text, attributes)
    local defaults = {
        group = {
            class="control-group"
        },
        label = {
            class="control-label"
        },
        controls = {
            class="controls"
        },
    }

    mergeAttributes(defaults, attributes)
    local group = createAttributesString(defaults["group"])
    local label = createAttributesString(defaults["label"])
    local controls = createAttributesString(defaults["controls"])

    local html = {
        format("<div %s><label %s>%s</label><div %s>", group, label, desc, controls),
        M.createSimpleLight(value,text,attributes),
        "</div></div>"
    }
    return html
end

--- Template
--    <div class="noUiSlider span2 no-margin horizontal"></div>
--    <div class="noUiSlider-text simple-desc">25 %</div>
--    <span class="help-inline"><strong>Alert Title ! </strong> Alert details and explainations</span>
-- @function [parent=#ui_helper] createSimpleSliderSelect
-- @param #string name
-- @param #table values
-- @param #string current
-- @param #table attributes
-- @param #string helpmsg
-- @return #table array for ngx.print
function M.createSimpleSliderSelect(name, values, current, attributes, helpmsg)
    local defaults = {
        slider = {
            class = "noUiSlider slider-select span2 no-margin horizontal",
        },
        slidertext = {
            class = "noUiSlider-text simple-desc",
	    id = "Slider_ID"
        },
        help = {
            class = "help-inline",
        },
        select = {
            class = "hide",
        },
    }
    mergeAttributes(defaults, attributes)
    local slider = createAttributesString(defaults["slider"])
    local slidertext = createAttributesString(defaults["slidertext"])
    local help = createAttributesString(defaults["help"])

    local html = {
        format("<div %s>", slider),
        M.createSimpleInputSelect(name,values,current,defaults),
        format("</div><div %s></div>", slidertext),
        M.createHelpText(helpmsg,attributes)
    }
    return html

end

--- Template
-- <div class="control-group">
--   <label class="control-label trigger-slider">Test Switch</label>
--   <div class="controls">
--    <div class="noUiSlider span2 no-margin horizontal"></div>
--    <div class="noUiSlider-text simple-desc">25 %</div>
--    <span class="help-inline"><strong>Alert Title ! </strong> Alert details and explainations</span>
--    </div>
--  </div>
-- @function [parent=#ui_helper] createSliderSelect
-- @param #string desc
-- @param #string name
-- @param #tabel values
-- @param #string current
-- @param #table attributes
-- @param #string helpmsg
-- @return #table for ngx.print
function M.createSliderSelect(desc, name, values, current, attributes, helpmsg)
    local defaults = {
        group = {
            class="control-group"
        },
        label = {
            class="control-label"
        },
        controls = {
            class="controls"
        },
    }

    if helpmsg ~= nil then
        defaults.group.class = defaults.group.class .. " error"
    end

    mergeAttributes(defaults, attributes)
    local group = createAttributesString(defaults["group"])
    local label = createAttributesString(defaults["label"])
    local controls = createAttributesString(defaults["controls"])

    local html = {
        format("<div %s><label %s>%s</label><div %s>",group, label, desc, controls),
        M.createSimpleSliderSelect(name, values, current, attributes, helpmsg),
        "</div></div>"
    }
    return html
end

---Template
--<div class="modal-tab" id="modal-loadlp" load-target="modals/mmpbx-service-modal.lp">Service</div>
-- or
-- <div class="modal-tab">Service</div>
--
-- <ul class="nav nav-tabs">
--  <li><div data-remote="url" ...></div></li>
--  <li><div data-remote="url" ...></div></li>
--  <li><div data-remote="url" ...></div></li>
-- </ul>
-- @function [parent=#ui_helper]   createModalTabs
-- @param #table tabs[.][desc]     name for tab
-- 		 tabs[.][id]       optional. if tabs[.][id] == "modal-loadlp", this tab could used be to load a modal page
-- 		 tabs[.][target]   optional. path for the modal page want to be loaded
-- @return #table for ngx.print
function M.createModalTabs (tabs)
    if (type(tabs) ~= "table") then
        return nil
    end
    local defaults = {
        ul = {
            class = "nav nav-tabs",
        }
    }
    local html = {
        format("<ul %s>", createAttributesString(defaults["ul"]))
    }
    for _, tab in ipairs (tabs) do
        if tab.active then
          defaults["li"] = {
            ["class"] = tab.active,
          }
        else
          defaults["li"] = {}
        end
        defaults["a"] = {
	  ["id"] = tab.desc,
          ["href"] = "#",
          ["data-remote"] = tab.target,
        }
        local desc = tab.desc or ""
        local li = createAttributesString(defaults["li"])
        local a = createAttributesString(defaults["a"])
        html[#html + 1] = format("<li %s><a %s>%s</a></li>", li, a, desc)
    end
    html[#html + 1] = [[</ul>]]
    return html
end


--- Template
-- <div class="modal-header">
--  <div class="row-fluid">
--    <div class="span11"><h2 class="span4">title</h2>
--    <span class="modal-action">
--      <span class="modal-action-advanced hide"><i class="icon-minus-sign"></i> hide advanced</span>
--      <span class="modal-action"><i class="icon-plus-sign"></i> show advanced</span>
--    </span>
--    </div>
--    <div class="span1"><a href="#" class="button btn-primary btn-close" data-dismiss="modal"><i class="icon-remove"></i></a></div>
--  </div>
--</div>
-- @function [parent=#ui_helper] createHeader
-- @param #string  name        the name to be displayed
-- @param #boolean hasAdvanced if the header should contain the show advanced/hide advanced text
-- @param #boolean hasRefresh  if the header should contain the refresh text (will trigger a GET on the modal)
-- @param #number autorefresh  if defined, indicates the time in second between refreshes (will trigger
--          a POST on the modal with a action=REFRESH as the parameter)
-- @param #table helpLink      if defined, the header contains the help text which links to the help page indicated by link
--          typical use: { data-toggle="modal", data-remote = "/help/index.lp"} or { href="/help/index.lp" }
  -- @return #table for ngx.print
function M.createHeader(name, hasAdvanced, hasRefresh, autorefresh, helpLink)
    setlanguage()
    local htmlautorefresh = ""
    if type(autorefresh) == "number" then
        htmlautorefresh = " data-autorefresh='" .. autorefresh .. "'"
    end

    local html = {
    [[
 <div class="modal-header" ]] .. htmlautorefresh .. [[>
  <div class="row-fluid">
    <div class="span11"><h2 class="span4"> ]] .. name .. [[</h2>
    ]]
    }

    -- Display the help button in the modal header if required
    if type(helpLink) == "table" then
        local attr = {}
        for k,v in pairs(helpLink) do
            if type(v) == "string" then
                attr[#attr+1] = format('%s="%s"', k, v)
            end
        end
        html[#html + 1] = format('<span id="help" class="modal-action" %s><i class="icon-question-sign"></i> %s</span>', concat(attr, " "), T"help")
    end

    -- Display the refresh button in the modal header if required
    if hasRefresh == true then
        html[#html + 1] = format([[
		<span class="modal-action">
			<span class="modal-action-refresh" id="Refresh_id"><i class="icon-refresh"></i> %s</span>
		</span>
		]], T"refresh data")
    end

    -- Display the show advanced button in the modal header if required
    if hasAdvanced == true then
        html[#html + 1] = format([[
        <span class="modal-action">
            <span class="modal-action-advanced hide" id="Hide_Advanced_id"><i class="icon-minus-sign"></i> %s</span>
            <span class="modal-action-advanced" id="Show_Advanced_id"><i class="icon-plus-sign"></i> %s</span>
        </span>
        ]], T"hide advanced", T"show advanced")
    end

    html[#html + 1] = [[
        </div>
    <div class="span1"><a href="#" class="button btn-primary btn-close" data-dismiss="modal"><i class="icon-remove"></i></a></div>
  </div>
</div>
    ]]

    return html
end

--- Template
-- <div class="modal-footer">
--  <div id="modal-no-change">
--    <div class="btn btn-primary btn-large" data-dismiss="modal">Close</div>
--  </div>
--  <div id="modal-changes" class="hide">
--    <div class="btn btn-large" data-dismiss="modal">Cancel</div>
--    <div id="save-config" class="btn btn-primary btn-large" data-dismiss="modal">Save and Close</div>
--  </div>
--</div>
-- @function [parent=#ui_helper] createFooter
-- @return #string for ngx.print
function M.createFooter()
    return format([[
     <div class="modal-footer">
      <div id="modal-no-change">
        <div id="close-config" class="btn btn-primary btn-large" data-dismiss="modal">%s</div>
      </div>
      <div id="modal-changes" class="hide">
        <div id="cancel-config" class="btn btn-large" data-dismiss="modal">%s</div>
        <div id="save-config" class="btn btn-primary btn-large">%s</div>
      </div>
    </div>
    ]], T"Close", T"Cancel", T"Save")
end

--- Template
--   <div class="header">
--      <div class="header-title pull-left" data-toggle="modal" data-remote="modals/device-modal.lp" data-id="device-modal"><p>Devices</p></div>
--		<div id="signal-strength-indicator-small-card"><div><div class="bar-small bar-small1"></div><div class="bar-small bar-small2"></div><div class="bar-small bar-small3"></div><div class="bar-small bar-small4"></div><div class="bar-small bar-small5"></div></div></div>
--      <div class="switch"><div class="switcher"></div><input value="0" type="hidden" name="uci_wan_auto"></div>
--      <div class="settings" data-toggle="modal" data-remote="modals/device-modal.lp" data-id="device-modal"><i class="icon-cogs"></i></div>
--    </div>
-- @function [parent=#ui_helper] createCardHeader
-- @param #string title
-- @param #string modalPath URL to the modal, if nil, then no modal will open and no configure icon displayed
-- @param #string switchName if nil, then no switch will be added
-- @param #string switchValue
-- @param #number mobile, to show the signal strength indicator
-- @return #string for ngx.print
function M.createCardHeader(title, modalPath, switchName, switchValue, attributes, mobile)
    local dataId
    if modalPath then
      dataId = modalPath:match("^.*/([^.]*).lp$")
    end
    local defaults = {
        header = {
            class = "header-title pull-left",
            ["data-toggle"] = "modal",
            ["data-remote"] = modalPath,
            ["data-id"] = dataId,
        },
        div = {
            class = "settings",
            ["data-toggle"] = "modal",
            ["data-remote"] = modalPath,
            ["data-id"] = dataId,
	    id = title
        },
        icon = {
            class = "icon-cogs"
        }
    }
    if switchName and modalPath then
        defaults.header.class = defaults.header.class .. " tooLongTitle"
    end

    if not modalPath or modalPath == "" then
        defaults.header["data-toggle"] = nil
        -- no need to do it for the cogs, they won't be displayed
    end

    mergeAttributes(defaults, attributes)
    local header = createAttributesString(defaults["header"])
    local div = createAttributesString(defaults["div"])
    local icon = createAttributesString(defaults["icon"])

    local html = {
      [[<div class="header">]],
      format("<div %s><p id=%s_tab>%s</p></div>", header, title, title)
    }
    if switchName and switchName ~= "" then
        html[#html + 1] = M.createSimpleSwitch(switchName,switchValue, attributes)
    end
    if modalPath and modalPath ~= "" then
        html[#html + 1] = format("<div %s><i %s ></i></div>", div, icon)
    end
	if mobile == 1 then
		html[#html + 1] = [[<div id="signal-strength-indicator-small-card"><div><div class="bar-small bar-small1"></div><div class="bar-small bar-small2"></div><div class="bar-small bar-small3"></div><div class="bar-small bar-small4"></div><div class="bar-small bar-small5"></div></div></div>]]
    end
	
	html[#html + 1] = [[</div>]]
    return html
end

--- Template
--   <div class="header">
--      <div class="header-title pull-left" data-toggle="modal" data-remote="modals/device-modal.lp" data-id="device-modal"><p>Devices</p></div>
--    </div>
-- @function [parent=#ui_helper] createCardHeader
-- @param #string title
-- @param #string modalPath URL to the modal, if nil, then no modal will open and no configure icon displayed
-- @return #string for ngx.print
function M.createCardHeaderNoIcon(title, modalPath, switchName, switchValue, attributes)
    local dataId
    if modalPath then
      dataId = modalPath:match("^.*/([^.]*).lp$")
    end
    local defaults = {
        header = {
            class = "header-title pull-left",
            ["data-toggle"] = "modal",
            ["data-remote"] = modalPath,
            ["data-id"] = dataId,
            style = "white-space:nowrap;",
        },
    }

    if not modalPath or modalPath == "" then
        defaults.header["data-toggle"] = nil
        -- no need to do it for the cogs, they won't be displayed
    end

    mergeAttributes(defaults, attributes)
    local header = createAttributesString(defaults["header"])

    local html = {
      [[<div class="header">]],
      format("<div %s><p><u>%s</u></p></div>", header, title)
    }
    html[#html + 1] = [[</div>]]
    return html
end

--- Template
--    <div class="socket socket-form">
--      <ul><li></li><li></li><li></li><li></li><li></li><li></li><li></li><li></li></ul>
--      <p>1</p>
--      <div class="socket-light off align-right" style="opacity:.5;"></div>
--      <% if  eth0State == "up" then
--      <div class="socket-light green align-right"></div>
--      <div class="socket-light green align-left"></div>
--      <% end %>
--      <div class="socket-light off align-left" style="opacity:.5;"></div>
--    </div>
-- @function [parent=#ui_helper] createSwitchPort
-- @param #string num port number
-- @param #string state
-- @param #string speed
-- @return #table for ngx.print
function M.createSwitchPort(num, state, speed, attributes)
    local defaults = {
        socket = {
            class="socket",
	    id = num
        },
        speed = {
            class="socket-light align-left"
        },
        state = {
            class="socket-light green align-right"
        }
    }

    local showSpeed = true
    if speed == "1000" then
        defaults.speed.class = defaults.speed.class .. " green"
    elseif speed == "100" then
        defaults.speed.class = defaults.speed.class .. " orange"
    else
        showSpeed = false
    end

    mergeAttributes(defaults, attributes)
    local socketAttr = createAttributesString(defaults["socket"])
    local speedAttr = createAttributesString(defaults["speed"])
    local stateAttr = createAttributesString(defaults["state"])

    local html = {
        format("<div %s><ul><li></li><li></li><li></li><li></li><li></li><li></li><li></li><li></li></ul>", socketAttr),
        format("<p>%s</p>", num),
        [[<div class="socket-light off align-right" style="opacity:.5;"></div>]],
        [[<div class="socket-light off align-left" style="opacity:.5;"></div>]]
    }
    if state == "up" or state == "OPERATION (O5)" then
        html[#html + 1] = format("<div %s></div>", stateAttr)
    end
    if showSpeed then
        html[#html + 1] = format("<div %s></div>", speedAttr)
    end
    html[#html + 1] = "</div>"
    return html
end

---
-- @function [parent=#ui_helper] createLanguageSelect
-- @param #string textdomain the page's textdomain
-- @param #string current the current language
-- @return #table for ngx.print
function M.createLanguageSelect(textdomain, current, attributes)
    local html = {}
    local languages = intl.listLanguages(textdomain)
    if languages and (#languages > 1) then
        html[#html + 1] = M.createSimpleInputSelect("webui_language", languages,current,attributes)
    end
    return html
end

---
-- @function [parent=#ui_helper] createBitLoadHistogram
-- @param #string data comma separated data feed
-- @return #table
function M.createBitLoadHistogram(datastring)
    local html = {}
    local minheight = 5
    local matrix = {}
    local iteration = 1
    local more = true
    local data = {}

    for val in gmatch(datastring,"%d+") do
        data[#data+1] = tonumber(val)
    end

    html[#html + 1] = '<pre style="letter-spacing:1px;color:gray;line-height:normal">'

    local ndata = #data
    -- prepare each line of data
    while more do
        local line = {}
        -- this will preallocate the array, should speed-up things
        line[1+ndata+1] = "\n" -- a PRE block does actually take carriage return into account

        more = false
        -- add line header
        line[1] = format("%2d", iteration) -- max 15 bits / tone, so might require 1 space of padding
        for i=1,ndata do
            if data[i] >= iteration then
                more = true
                line[i+1] = "&#9608;" -- this is a full character
            else
                line[i+1] = " "
            end
        end
        if more then
            matrix[iteration] = concat(line, '')
            iteration = iteration + 1
        end
    end

    while iteration <= minheight do
        matrix[iteration] = { format("%2d\n", iteration)} -- add up until we reach minheight
        iteration = iteration + 1
    end

    for i=#matrix,1,-1 do
        html[#html+1] = matrix[i]
    end

    -- now, we add a line with the value (when > 9, we just put a +)
    local line = { "  " }
    line[1+ndata+1] = "\n"
    for i=1,ndata do
        if data[i] > 9 then
            line[i+1] = "+"
        else
            line[i+1] = data[i]
        end
    end

    html[#html+1] = concat(line, '')

    -- now we add a vertical spacer every 16 bins, starting with the first one
    line = { "  " }
    local patternspacer = "|               " -- 1 spacer followed by 15 spaces
    local numdata = #data
    while numdata > 0 do -- no edge case support since we're expecting 512 or 4096
        line[#line+1] = patternspacer
        numdata = numdata - 16
    end
    line[#line+1] = "\n"

    html[#html+1] = concat(line,'')

    -- now we add the bucket number, starting with 0
    line = { "  " }
    local number = 0
    local spacepatterns = {
        [13] = "   ",
        [14] = "  ",
        [15] = " ",
        [16] = ""
    }
    while number < ndata do
        local tmp = number .. "            "
        line[#line+1] = tmp .. spacepatterns[#tmp]
        number = number + 16
    end
    line[#line+1] = "\n"

    html[#html+1] = concat(line,'')

    html[#html + 1] = "</pre>"
    return html
end

---
-- @function [parent=#ui_helper] createMessages
-- @param messages array of messages with for each message, level and content
-- @return #table for ngx.print
function M.createMessages(messages)
    local content = {}
    for _,v in ipairs(messages) do
        local mess = v.content
        local level = v.level or "warning"

        if mess then
            content[#content+1] = format('<div class="alert alert-%s">', level)
            content[#content+1] = mess
            content[#content+1] = "</div>"
        end
    end
    return content
end

--- Create a input select + button control
--  Template:
--	 		  <div class="control-group">
--	 		   	<label class="control-label">{Description}</label>
--	 		   	<div class="controls">
--	 		  		<select name="{Name}" class="span3">
--						<option value="{value[i]" {selected} >{text[i]}</option>
--	 		  		</select>
--	 		  		<span class="help-inline"><strong>Alert Title ! </strong> Alert details and explainations</span>
--    			</div>
--   			 <div class="controls">
--   				   <div class="btn"><i class="{icon}"></i>  {label}</div>
--	 		   	</div>
--	 		  </div>
-- @function [parent=#ui_helper] createInputSelectWithButton
-- @param #string desc
-- @param #string name
-- @param #table values
-- @param #string current
-- @param #string buttontext
-- @param #string icon
-- @param #table attributes
-- @param #string helpmsg
-- @return #table

function M.createInputSelectWithButton(desc, name, values, current, buttontext, icon, attributes, helpmsg)
    local defaults = {
        group = {
            class="control-group"
        },
        label = {
            class="control-label"
        },
        controls = {
            class="controls"
        },
    }

    if helpmsg ~= nil then
        defaults.group.class = defaults.group.class .. " error"
    end

    mergeAttributes(defaults, attributes)
    local group = createAttributesString(defaults["group"])
    local label = createAttributesString(defaults["label"])
    local controls = createAttributesString(defaults["controls"])

    local html = {
        format("<div %s><label %s>%s</label><div %s>",group, label, desc, controls),
        M.createSimpleInputSelect(name, values, current, attributes),
	M.createSimpleButton(buttontext,icon,attributes),
	M.createHelpText(helpmsg,attributes),
        "</div></div>"
    }
    return html
end


---
--	Template
-- 			  <div class="control-group">
--			   	 <label class="control-label">{Description}</label>
--			   	 <div class="controls">
--				   	<span class="span2 simple-desc">{Value}</span>
--   			 <div class="controls">
--   				   <div class="btn"><i class="{icon}"></i>  {label}</div>
--	 		   	</div>
--	 		  		<span class="help-inline"><strong>Alert Title ! </strong> Alert details and explainations</span>
--			   	 </div>
--			  </div>
-- @function [parent=#ui_helper] createLabelWithButton
-- @param #string desc: text used for the label description
-- @param #string value: text used for the label values
-- @param #string buttontext
-- @param #string icon
-- @param #table attributes: maps additional attributes to apply
-- @param #string helpmsg
-- @return #string
function M.createLabelWithButton(desc, value, buttontext, icon, attributes, helpmsg)
    local defaults = {
        group = {
            class="control-group"
        },
        label = {
            class="control-label"
        },
        controls = {
            class="controls"
        },
        span = {
            class = "span2 simple-desc",
        },
        help = {
            class = "help-inline"
        }
    }

    if helpmsg ~= nil then
        defaults.group.class = defaults.group.class .. " error"
    end

    mergeAttributes(defaults, attributes)
    local group = createAttributesString(defaults["group"])
    local label = createAttributesString(defaults["label"])
    local controls = createAttributesString(defaults["controls"])
    local span = createAttributesString(defaults["span"])
    local help = createAttributesString(defaults["help"])

    local html = {
        format("<div %s><label %s>%s</label><div %s><span %s>%s</span>",group, label, desc, controls, span, value),
	M.createSimpleButton(buttontext,icon,attributes),
        M.createHelpText(helpmsg,attributes),
        "</div></div>"
    }
    return html
end


return M


