local M = {}

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

return M