#!/usr/bin/env lua
--[[
Copyright (c) 2016 Technicolor Delivery Technologies, SAS

The source code form of this Transformer component is subject
to the terms of the Clear BSD license.

You can redistribute it and/or modify it under the terms of the
Clear BSD License (http://directory.fsf.org/wiki/License:ClearBSD)

See LICENSE file for more details.
]]

local print, ipairs, setmetatable, unpack, pairs =
      print, ipairs, setmetatable, unpack, pairs
local table = table
local format = string.format

local proxy = require 'datamodel-bck'
local unixsocket = require("tch.socket.unix")
local msg = require('transformer.msg').new()
local bit = require("bit")

local function do_help()
    print [=[
List of commands:
    get <path>
    count <path>
    getpn <path> [nextlevel]
    list <path>
    set <path> <value>
    add <path> [name]
    del <path>
    resolve <path> <key>
    apply
    subscribe <path> [type [options]]
      'type' is one of [set, add, delete, all], default is 'all'
      'options' is a comma separated list of [no_own_events]
    unsubscribe <id>
    checkevents
    template <path> [strict]
    exit
    help
]=]
end

local function socket_error(action, s)
  print(format("socket error for %s: %s", action, s))
end

local event_address

local function set_event_address(uuid)
  if not event_address then
    event_address = "tfcli_event_listener_"..uuid
  end
end
local event_socket
local function get_event_socket()
  if not event_socket and event_address then
    local ok, errmsg
    event_socket, errmsg = unixsocket.dgram(bit.bor(unixsocket.SOCK_NONBLOCK, unixsocket.SOCK_CLOEXEC))
    if not event_socket then
      socket_error("create", errmsg)
      return
    end
    ok, errmsg = event_socket:bind(event_address)
    if not ok then
      socket_error("bind", errmsg)
      event_socket.close()
      event_socket = nil
    end
  end
  return event_socket
end

local function do_checkevents()
  local sock = get_event_socket()
  if not sock then
    return
  end
  local data, from = sock:recvfrom()
  while data do
    local tag, _, _ msg:init_decode(data)
    if tag == msg.EVENT then
      local event = msg:decode()
      if event then
        print(format("EVENT: id=%s, type=%s, path=%s, value=%s", event.id, event.eventmask, event.path, event.value))
      end
    end
    data, from = sock:recvfrom()
  end
  if not data then
    if from ~= "WOULDBLOCK" then
      socket_error("receive", from)
    end
  end
end

local function do_set(uuid, path, value)
    if not path then
        print("path required")
        return
    end
    if not value then
        value = ""
    end

    local result, errors = proxy.set(uuid, path, value)
    if not result then
      for _, err in ipairs(errors) do
        print(err.path, err.errcode, err.errmsg)
      end
    end
end

local function do_get(uuid, path)
    if not path then
        print "path required"
        return
    end

    local results, errmsg = proxy.get(uuid, path)
    if not results then
      print("ERROR", errmsg)
    else
      for _, param in ipairs(results) do
          print(format("%s%s [%s] = %s", param.path, param.param, param.type, param.value))
      end
    end
end

local function do_getPC(uuid, path)
    if not path then
        print "path required"
        return
    end
    local count = proxy.getPC(uuid, path)
    if not count then
      print("ERROR", path)
      return
    end
    print(format("Number of parameters :%d", count))
end

local function do_getPN(uuid, path, nextlevel)
    if not path then
      print "path required"
      return
    end
    if nextlevel and (nextlevel == "true" or nextlevel == "1" or nextlevel == "y")  then
      nextlevel = true
    else
      nextlevel = false
    end
    local results, errmsg = proxy.getPN(uuid, path, nextlevel)
    if not results then
      print("ERROR", errmsg)
    else
      for _, param in ipairs(results) do
          local writable
          if param.writable then
            writable = "[w] "
          else
            writable = "[ ] "
          end
          print(writable..param.path..param.name)
      end
    end
end

local function do_getPL(uuid, path)
    if not path then
        print "path required"
        return
    end

    local results, errmsg = proxy.getPL(uuid, path)
    if not results then
      print("ERROR", errmsg)
    elseif next(results) == nil then
      print("path doesn't contain any parameters")
    else
      for _, param in ipairs(results) do
          print(format("%s%s ", param.path, param.param))
      end
    end
end

local function do_add(uuid, path, name)
    if not path then
        print "path required"
        return
    end

    local result, errmsg = proxy.add(uuid, path, name)
    if not result then
        print("ERROR", errmsg)
    else
        print(format("Created %s%s", path, result))
    end
end

local function do_del(uuid, path)
    if not path then
        print "path required"
        return
    end

    local result, errmsg = proxy.del(uuid, path)
    if not result then
        print("ERROR", errmsg)
    end
end

local function do_resolve(uuid, path, key)
    if not path then
        print "path required"
        return
    end
    if not key then
        print "key required"
        return
    end

    local result, errmsg = proxy.resolve(uuid, path, key)
    if not result then
        print("ERROR", errmsg)
    else
        print(result)
    end
end

local function do_apply(uuid)
  proxy.apply(uuid)
end

local function translate_type_to_mask(subscr_type)
  local mask = {
    set = 1,
    add = 2,
    delete = 4,
    all  = 7,
  }
  local subscr_mask = mask[subscr_type or "all"]
  if not subscr_mask then
    print("ERROR unknown subscription type ", subscr_type)
  end
  return subscr_mask
end

-- process options string (comma separated list)
local function translate_options_to_mask(options)
  if not options then
    return 0
  end
  local options_table = {}
  for option in string.gfind(options, "[^,]+") do
    options_table[option] = true
  end

  local options_mask = 0
  if (options_table["no_own_events"]) then
    options_mask = options_mask + 1
  end

  return options_mask
end

local function do_subscribe(uuid, path, subscription_type, options)
  if not path then
    print "path required"
    return
  end
  local typemask = translate_type_to_mask(subscription_type)
  if not typemask then
    return
  end
  local optionsmask = translate_options_to_mask(options)
  if not optionsmask then
    return
  end

  if not get_event_socket() then
    print "ERROR: no event socket, cannot subscribe"
    return
  end

  local id, paths = proxy.subscribe(uuid, path, event_address, typemask, optionsmask)
  if not id then
    print("ERROR", paths)
    return
  end
  print(format("Subscription id: %d", id))
  if paths and type(paths)=="table" and next(paths) then
    print("Non evented paths:")
    for _,path in ipairs(paths) do
      print(format("        %s", path))
    end
  end
end

local function do_unsubscribe(uuid, subscr_id)
  if not subscr_id then
    print "id required"
    return
  end
  local res, errmsg = proxy.unsubscribe(uuid, tonumber(subscr_id))
  if not res then
    print("ERROR", errmsg)
  end
end

local function do_template(uuid, path, strict)
  if not path then
    print "path required"
    return
  end
  if strict and (strict == "true" or strict == "1" or strict == "y")  then
    strict = true
  else
    strict = false
  end
  local result_paths = {}

  -- Perform a get parameter values of the given path.
  local paths = proxy.get(uuid, path)
  if not paths then
    print "You can not generate a testsuite template if the get doesn't even work."
  end
  -- Rearrange the returned paths, so the result can more easily be merged with
  -- the result of get parameter names.
  for _, full_path in ipairs(paths) do
    result_paths[full_path.path..full_path.param] = {type = full_path.type, value = full_path.value}
  end
  -- Perform a get parameter names of the path. We want all children, so pass level false.
  local gpns = proxy.getPN(uuid, path, false)
  if not gpns then
    print "You can not generate a testsuite template if the gpn doesn't even work."
  end
  -- Merge the returned results with the info from the get parameter values.
  for _, full_path in ipairs(gpns) do
    if full_path.name then
      local pathinfo = result_paths[full_path.path..full_path.name]
      if pathinfo then
        pathinfo.writable = full_path.writable
      end
    end
  end
  for result_path, info in pairs(result_paths) do
    local println = result_path.." ["..info.type.."] = "
    if info.writable then
      println = println .. info.value .. " (set)"
    elseif strict then
      println = println .. info.value
    else
      println = println .. "*"
    end
    print(println)
  end
end

local actions = {
    get = do_get,
    count = do_getPC,
    list = do_getPL,
    getpn = do_getPN,
    set = do_set,
    add = do_add,
    del = do_del,
    resolve = do_resolve,
    apply = do_apply,
    subscribe = do_subscribe,
    unsubscribe = do_unsubscribe,
    checkevents = do_checkevents,
    template = do_template,
    help = do_help,
    __index = function(_, action)
      return function()
        print(format("invalid command: %s, use 'help' to see valid commands", tostring(action)))
      end
    end
}
setmetatable(actions, actions)

local function handle_command(cmd,uuid)
    local c={}
    for s in cmd:gmatch("(%S*)") do
        if #s>0 then
            c[#c+1] = s
        end
    end

    if #c==0 then
        return
    end
    local action = table.remove(c, 1)
    actions[action](uuid,unpack(c))
end

local function cli(args)
    local fd = assert(io.open("/proc/sys/kernel/random/uuid", "r"))
    local uuid = fd:read('*l')
    uuid = string.gsub(uuid,"-","")
    fd:close()
    set_event_address(uuid)
    if #args > 0 then
      handle_command(table.concat(args , " "), uuid)
      return
    end
    do_help()
    while true do
        io.write("transformer> ")
        local line = io.read('*l')
        if not line or line=='exit' then
            break
        end
        handle_command(line,uuid)
        do_checkevents()
    end
end

cli({...})
