local M = {}

local function parseCommandToTchLib(command)
	local args={}
	local comm

	for str in string.gmatch(command, '([^"%s"]+)') do
		if not comm then
			comm = str
		else
			args[#args+1] = str
		end
	end

	return comm, args
end

function M.isModuleAvailable(name)
  if package.loaded[name] then
    return true
  else
    for _, searcher in ipairs(package.searchers or package.loaders) do
      local loader = searcher(name)
      if type(loader) == 'function' then
        package.preload[name] = loader
        return true
      end
    end
    return false
  end
end
local isModuleAvailable = M.isModuleAvailable 

function M.getRightLoggerModule()
	if isModuleAvailable("tch.logger") then
		return require("tch.logger")
	elseif isModuleAvailable("transformer.logger") then
		return require("transformer.logger")
	end
	return nil
end

-- Use new library if detected
-- New library needs first argument as the main command as second argument a table with the argument of the commands
-- parseCommandToTchLib take care of this conversion
-- If lib is not present fallback to the stock implementation that is insecure
-- Ex echo ciao acca
-- process.execute("echo",{"ciao","acca"})
function M.execute(FullCommand)
	if isModuleAvailable("tch.process") then
		return require("tch.process").execute(parseCommandToTchLib(FullCommand))
	end
	return os.execute(FullCommand)
end

function M.popen(FullCommand)
	if isModuleAvailable("tch.process") then
		return require("tch.process").popen(parseCommandToTchLib(FullCommand))
	end
	return os.popen(FullCommand)
end

return M