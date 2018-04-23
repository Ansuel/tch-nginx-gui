--gettext like interface

local format = string.format
local error = error
local sort = table.sort
local ipairs = ipairs

local lfs = require 'lfs'
local trfile = require 'web.trfile'
local plural = require 'web.plural'

local M = {}

local langPath = '/www/lang'

-- set (or get) the language path to find localization files
-- @param path if not nil, a string containing the path to set
-- @returns the path set
function M.setLangPath(path)
    if path then
        -- set the path, remove a terminating /
        langPath = path:gsub('/$', '')
    end
    return langPath
end

-- the translations cache
local trcache = setmetatable({}, {__mode='v'})

--- get the filename for a translation
-- @param domain string the text domain
-- @param language string the language code
-- @returns the filename taking into account the language path
local function translationFilename(domain, language)
    return format('%s/%s/%s.mo', langPath, language, domain)
end

--- set the domain
-- @param env, the gettext environment
-- @param dom string, the text domain to set or nil for no change in domain
-- @returns the most recently set domain
-- Note: translations are discarded if domain changes
local function textdomain(env, dom)
    if dom and (env.dom ~= dom) then
        -- domain changed, translation need to be reloaded
        env.dom = dom
        env.tr = nil
    end
    return env.dom
end

--- set the language code
-- @param env, the gettext environment
-- @param lang string, the language code to set or nil for no change
-- @returns the most recently set language code
-- Note: translations are discarded if language changes
local function language(env, lang)
    if lang and (env.lang ~= lang) then
        -- language changed, translations need to be reloaded
        env.lang = lang
        env.tr = nil
    end
    return env.lang
end

--- load/reload the translations
-- @param env, the gettext environment
local function load_translations(env)
    if env.tr then
        -- nothing changed
        return env.tr
    end

    local filename = translationFilename(env.dom, env.lang)

    local translations = trcache[filename]

    if not translations then
        local err
        translations, err = trfile.load(filename)
        if not translations then
            if err and (env.dom~='<notset>') and (env.lang~='<notset>') then
                env.log_error(err)
            end
            -- prevent if from loading again
            translations = {}
        end
        trcache[filename] = translations
    end
    env.tr = translations
    env.meta = translations['']
    translations[''] = nil -- wipe out otherwise translation for '' will be meta ...
    env.plural = nil --wipe out plural, it will only be loaded when needed
    return translations
end

--- fallback for plural forms in case of an error
local function plural_fallback(n)
    return (n==1) and 0 or 1
end

--- load the plural expression evaluator
-- @param env, the gettext environment
-- @returns the translations and plural function
local function load_plural(env)
    local pl_exp
    local tr = load_translations(env)
    pl_exp = env.plural
    if not pl_exp then
        local meta = env.meta
        local p = meta and meta:match('\n%s*Plural%-Forms:(.*)\n')
        if p then
            pl_exp = plural.compile(p)
        end
        if not pl_exp then
            pl_exp = plural_fallback
        end
        env.plural = pl_exp
    end
    return tr, pl_exp
end


--- get a string translation
-- @param env, the gettext environment
-- @param s, the string to translate
local function gettext(env, s)
    local tr = load_translations(env)
    return tr[s:untaint()] or s
end

--- get a string translations taking into account the plural form(s)
-- @param env, the gettext environment
-- @param s1 string the singular original
-- @param s2 string the plural original
-- @param n the number used to select the correct plural form
local function ngettext(env, s1, s2, n)
    local tr, pl_exp = load_plural(env)
    local idx = pl_exp(n)+1
    local s = tr[s1:untaint()] or {s1, s2}
    return s[idx] or s[#s] --fallback to last
end

local function no_log()
end

--- Create a gettext environment
-- @param log_error, function taking a string argument. Used for logging errors
-- @returns a gettext environment
function M.load_gettext(log_error)
    local intlData = {
        log_error = log_error or no_log,
        dom = '<notset>',
        lang = '<notset>',
    }
    local env = {
        --- select the textdomain
        textdomain = function(dom)
            return textdomain(intlData, dom)
        end;
        --- select the language
        language = function(lang)
            return language(intlData, lang)
        end;
        --- get a translation
        gettext = function(s)
            return gettext(intlData, s)
        end;
        --- get a translation with plurals
        ngettext = function(s1, s2, n)
            return ngettext(intlData, s1, s2, n)
        end;
    }

    return env
end

--- Check if there is a translation available for the given domain and language
-- @param domain String, the text domain
-- @param language String, the language
-- @returns true if a translation file is available, false if not,
--          plus the name of the file
local function haveTranslation(domain, language)
    local tr = translationFilename(domain, language)
    return lfs.attributes(tr, 'mode')=='file', tr
end

local function haveLanguage(domain, language)
    if language == "en-us" then
        return true
    else
        return haveTranslation(domain, language)
    end
end

--- Find the best available language
-- @param domain String, the text domain
-- @param preferred String, the user preferred language
-- @param acceptable String the Accept-Language header from the HTPP request
-- @returns the best available language
-- if not translations are found for any of the languages in preferred or
-- acceptable, en-US is returned.
function M.findLanguage(domain, preferred, acceptable)
    if preferred then
        if haveLanguage(domain, preferred) then
            -- the translations file exist for the preferred language
            -- or the preferred was US English, in which case the file
            -- does not need to exist.
            return preferred
        end
    end
    -- translations for the preferred language not found, or no preferred
    -- language specified.
    -- build a list of acceptable languages.
    acceptable = acceptable or ''
    local langlist = {}
    -- acceptable should be a list of comma separated language specs
    for s in acceptable:gmatch('([^,]+),?') do
        local lang, weight
        local sc = s:find(';')
        if sc then
            lang = s:sub(1, sc-1)

            weight = tonumber( s:sub(sc+1):match('q=(0%.%d*)') or '0')
        else
            lang = s
            weight = 1
        end
        -- make sure lang somewhat matches the expected form ll-LL
        local locale
        lang, locale = lang:match('^%s*([%a]*)[-_]?([%w@]*)%s*$')
        if lang then
            if locale~='' then
                lang = format("%s-%s", lang, locale)
            end
            lang = lang:lower()
            langlist[#langlist+1] = {lang, weight}
        end
    end
    -- sort list in order of preference (high to low)
    sort(langlist, function(first, second) return first[2]>second[2] end)

    -- try to find a translation
    for _, ls in ipairs(langlist) do
        if haveLanguage(domain, ls[1]) then
            return ls[1]
        end
    end

    -- no language found, return the global default
    return 'en-us'
end

--- list the languages installed for a textdomain
-- @param textdomain string, the domain
-- @returns a list with language code, language name pairs.
-- the list at least contains 'en-us', the default language, even if no
-- translations have been installed.
function M.listLanguages(textdomain)
    local languages = {}
    local have_en_US = false
    if lfs.attributes(langPath, 'mode')=='directory' then
        for lang in lfs.dir(langPath) do
            if not lang:find('^%.') then
                local have_tr, filename = haveTranslation(textdomain, lang)
                if have_tr then
                    local langName = trfile.getLanguage(filename) or lang
                    languages[#languages+1] = {lang, langName}
                    if lang=='en-us' then
                        have_en_US = true
                    end
                end
            end
        end
    end
    if not have_en_US then
        languages[#languages+1] = { 'en-us', 'English (US)'}
    end
    return languages
end

return M
