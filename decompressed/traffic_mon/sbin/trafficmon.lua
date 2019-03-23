#! /usr/bin/lua

local lfs = require("lfs")

local processinfo = require("transformer.shared.processinfo")

local datadir  = "/tmp/trafficmon/"

-- the file will recode 145 line data
--  line 1: the last moment total traffic data
--  line 2~145: 144 times data, every 10mins during 24hours.
local datanum  = 145

local binit = false

if arg[1] == "-i" then
	binit = true
end

local function getMemTotal()
	local ret = "0"
	
	local f = io.open("/proc/meminfo","r")
	if f then
		for line in f:lines() do
			if line:match("MemTotal") then
				ret = line:gsub("MemTotal:%s*",""):gsub("[A-z]+%s*","")
				break
			end
		end
		f:close()
	end
	
	return ret
end

local function getMemFree()
	local ret = "0"
	
	local f = io.open("/proc/meminfo","r")
	if f then
		for line in f:lines() do
			if line:match("MemFree") then
				ret = line:gsub("MemFree:%s*",""):gsub("[A-z]+%s*","")
				break
			end
		end
		f:close()
	end
	
	return ret
end

--Create file
--fname = name of file to create
--total = first line of the file to write
--optional: statsData = write the second line in file.
--optional: times = write the second line in file. 
local function inizializeFile(fname,total,statsData,times)
	local f = io.open(fname, "w")
	if f then
		f:write(total .. "\n")
		if statsData then
			f:write(statsData .. " " .. times .. "\n")
		end
		f:close()
	end
end

local function handleStatsFile(name, statsData,times)
	local fname = datadir .. name
	
	local Total
	
	if name:match("mem") then
		Total = getMemTotal()
	else
		Total = "100"
	end
	
	if binit then
		inizializeFile(fname,Total,statsData,times)
	else
		f = io.open(fname, "r")
		if not f then
			inizializeFile(fname,Total,statsData,times)
			f = io.open(fname, "r")
		end
		if f then
			local data = {}
			for line in f:lines() do
				data[#data+1] = line
			end
			f:close()
			f = io.open(fname, "w")
			
			if f then
				f:write(Total .. "\n")
				local insert = false
				for index,value in ipairs(data) do
					if index > 1 and index <= datanum then
						local oldtimes = tonumber((value:gsub("[0-9]+%s",""):gsub(":","")))--v:match(".*%s")--:gsub("%s+",""):gsub(":","")
						local ntimes = tonumber((times:gsub(":","")))
						if oldtimes == ntimes then
							if not insert then
								f:write(statsData .. " " ..  times .. "\n")
								insert = true
							end
						elseif oldtimes > ntimes then
							if not insert then
								f:write(statsData .. " " ..  times .. "\n")
								insert = true
							end
							f:write(value .. "\n")
						else
							f:write(value .. "\n")
						end
					end
				end
				if not insert then
					f:write(statsData .. " " ..  times .. "\n")
					insert = true
				end
				f:close()
			end
		end
	end
end

local function DataCollector(datadir, binit)
	local dirname  = "/sys/class/net/"
	local tailname = "/statistics/"

	local types = {"tx_bytes", "rx_bytes"};
	
	local times = os.date('%H:%M')

	local ntotal, ntraffic = 0, 0
	local f, fname = nil, ""

	for name in lfs.dir(dirname) do
		if name ~= "." and name ~= ".." then
			for _,dtype in ipairs(types) do
				fname = dirname .. name .. tailname .. dtype
				f = io.open(fname, "r")
				if f then
					ntotal = f:read("*line")
					f:close()
				end

				fname = datadir .. name .. "_" .. dtype
				if binit then
					inizializeFile(fname,ntotal)
				else
					f = io.open(fname, "r")
					if not f then
						inizializeFile(fname,ntotal)
						f = io.open(fname, "r")
					end
					if f then
						local data = {}
						for line in f:lines() do
							data[#data+1] = line
						end
						f:close()
						ntraffic = tonumber(ntotal) - data[1]
						if (ntraffic < 0) then
							ntraffic = 0
						end
						f = io.open(fname, "w")
						if f then
							f:write(ntotal .. "\n")

							local insert = false
							for index,value in ipairs(data) do
								if index > 1 and index <= datanum then
									local oldtimes = tonumber((value:gsub("[0-9]+%s",""):gsub(":","")))--v:match(".*%s")--:gsub("%s+",""):gsub(":","")
									local ntimes = tonumber((times:gsub(":","")))
									if oldtimes == ntimes then
										if not insert then
											f:write(ntraffic .. " " ..  times .. "\n")
											insert = true
										end
									elseif oldtimes > ntimes then
										if not insert then
											f:write(ntraffic .. " " ..  times .. "\n")
											insert = true
										end
										f:write(value .. "\n")
									else
										f:write(value .. "\n")
									end
								end
							end
							if not insert then
								f:write(ntraffic .. " " ..  times .. "\n")
								insert = true
							end
							f:close()
						end
					end
				end
			end
		end
	end
	
	handleStatsFile("stats_cpu",processinfo.getCPUUsage(),times)
	handleStatsFile("stats_mem",getMemFree(),times)
end

-- lock file directory
local lock = lfs.lock_dir(datadir)
if lock then
	pcall(DataCollector, datadir, binit)
	-- unlock file directory
	lock:free()
end
