local M={}
local ipairs, next, table = ipairs, next, table
--- Function executes the specified command and parses its output based on lookup and keys
-- @param cmdlookup   A table of the form {command="command to execute",lookup={parsing rules}}
--                    command  A string specifying the command to execute.
--                    lookup   A table specifying the rules to parse the output of command.
--                             This table contains entries of the form
--                             ["keyname"]={pat="regex"[,act=postprocessingfunction(string)][,subkeys={"subkey1","subkey2"}]}
--                             Each entry represents a parsing rule for a particular key "keyname". These rules are records
--                             containing the following members:
--
--                             pat                Contains a pattern that will extract the corresponding value from the command output.
--                             act (optional)     Is a pointer to a function which applies post-processing on the value extracted by the pat
--                             subkeys (optional) Is needed if there are multiple values extracted from the same line of output.
--                                                These values are then stored in values["keyname"][subkeys[i]]
--
-- @param keys    An array of keynames to be retrieved from the output
-- @param xdslInfo A table to return the extracted values for each keyname in keys
-- examples in xdslctl.lua
function M.parseCmd(cmdlookup, keys, xdslInfo)
  local debug = false
  local cmd = cmdlookup.command
  local lookup = cmdlookup.lookup
  local pipe = io.popen(cmd)
  if not pipe then
    -- failed to open pipe return nil
    for _, key in ipairs(keys) do
      xdslInfo[key] = nil
    end
    return
  end
  local line = pipe:read("*line")
  local val, act, subkeys
  -- deep copy keys as it will be altered
  local dupkeys = {}
  for _, k in ipairs(keys) do
    dupkeys[#dupkeys + 1] = k
  end
  while line do
    if line:len() > 0 then
      for index, key in ipairs(dupkeys) do
        if lookup[key] then
          subkeys=lookup[key].subkeys
          if subkeys then
            -- multiple values extracted from a single line
            val = {line:match(lookup[key].pat)}
            if next(val) then
              xdslInfo[key] = {}
              -- remove key from search keys as the value has been found
              table.remove(dupkeys, index)
              act = lookup[key].act
              for subLine, pattern in ipairs(val) do
                xdslInfo[key][subkeys[subLine]] = act and act(pattern) or pattern
              end
              break
            end
          else
            -- single value extracted
            val = line:match(lookup[key].pat)
            if val then
              -- remove key from search keys as the value has been found
              table.remove(dupkeys, index)
              act=lookup[key].act
              xdslInfo[key] = act and act(val) or val
              break
            end
          end
        end
      end
      if not next(dupkeys) then
        break
      end
    end
    line = pipe:read("*line")
  end
  -- if there are keys left in dupkeys which have not been resolved
  -- fill in the corresponding values with nil
  for _, key in ipairs(dupkeys) do
    xdslInfo[key] = nil
  end
  if debug then
    for _, key in ipairs(keys)
    do
      if not xdslInfo[key] then
        print("Param " .. key .. " not found")
      end
    end
  end
  pipe:close()
end

return M
