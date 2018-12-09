#! /usr/bin/lua

local lfs = require("lfs")
local datadir  = "/tmp/trafficmon/"

local binit = false

if arg[1] == "-i" then
    binit = true
end

local function DataCollector(datadir, binit)
    local dirname  = "/sys/class/net/"
    local tailname = "/statistics/"

    -- the file will recode 145 line data
    --  line 1: the last moment total traffic data
    --  line 2~145: 144 times data, every 10mins during 24hours.
    local datanum  = 145
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
                    f = io.open(fname, "w")
                    if f then
                        f:write(ntotal .. "\n")
                        f:close()
                    end
                else
                    f = io.open(fname, "r")
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
end

-- lock file directory
local lock = lfs.lock_dir(datadir)
if lock then
    pcall(DataCollector, datadir, binit)
    -- unlock file directory
    lock:free()
end
