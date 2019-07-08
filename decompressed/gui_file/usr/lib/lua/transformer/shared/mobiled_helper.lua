local M = {}

local dataMaxAge = {}

function M.setDataMaxAge(dev_idx, age)
	dataMaxAge[dev_idx] = age
end

function M.getDataMaxAge(dev_idx)
	return dataMaxAge[dev_idx]
end

return M
