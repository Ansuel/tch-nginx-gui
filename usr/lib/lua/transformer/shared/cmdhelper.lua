local M={}
--- Function executes the specified command and parses its output based on lookup and keyarray
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
-- @param keyarray    An array of keynames to be retrieved from the output
-- @param valuearray  A table to return the extracted values for each keyname in keyarray
-- examples in xdslctl.lua
function M.parseCmd(cmdlookup,keyarray,valuearray)
  local debug=false
  local cmd=cmdlookup.command
  local lookup=cmdlookup.lookup
  local pipe = io.popen(cmd)
  if pipe==nil then
    -- failed to open pipe return nil
    for _,k in ipairs(keyarray) do
      valuearray[k]=nil
    end
    return
  end
  local line=pipe:read("*line")
  local val,act,subkeys
  -- deep copy keyarray as it will be altered
  local dupkeyarray={}
  for _,k in ipairs(keyarray) do
    dupkeyarray[#dupkeyarray+1]=k
  end
  while line do
    if line:len()>0 then
      for i,k in ipairs(dupkeyarray) do
        if lookup[k]~=nil then
          subkeys=lookup[k].subkeys
          if subkeys~=nil then
            -- multiple values extracted from a single line
            val={string.match(line,lookup[k].pat)}
            if next(val)~=nil then
              valuearray[k]={}
              -- remove key from search keys as the value has been found
              table.remove(dupkeyarray,i)
              act=lookup[k].act
              if act~=nil then
                for j,v in ipairs(val) do
                  valuearray[k][subkeys[j]]=act(v)
                end
              else
                for j,v in ipairs(val) do
                  valuearray[k][subkeys[j]]=v
                end
              end
              break
            end
          else
            -- single value extracted
            val=string.match(line,lookup[k].pat)
            if val~=nil then
              -- remove key from search keys as the value has been found
              table.remove(dupkeyarray,i)
              act=lookup[k].act
              if act~=nil then
                  valuearray[k]=act(val)
              else
                  valuearray[k]=val
              end
              break
            end
          end
        end
      end
      if next(dupkeyarray)==nil then
        break
      end
    end
    line=pipe:read("*line")
  end
  -- if there are keys left in dupkeyarray which have not been resolved
  -- fill in the corresponding values with nil
  for _,k in ipairs(dupkeyarray) do
    valuearray[k]=nil
  end
  if debug==true
  then
    for _,k in ipairs(keyarray)
    do
      if valuearray[k]==nil
      then
        print("Param " .. k .. " not found")
      end
    end
  end
  pipe:close()
end

return M
