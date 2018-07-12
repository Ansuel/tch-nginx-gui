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
    local i, j, data = 0, 0, {}
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
                        f:write(ntotal .. "\n" .. ntotal .. "\n")
                        f:close()
                    end
                else
                    f = io.open(fname, "r")
                    if f then
                        i = 0
                        for line in f:lines() do
                            i = i + 1
                            data[i] = line
                        end
                        f:close()
                        ntraffic = tonumber(ntotal) - data[1]
                        if (ntraffic < 0) then
                            ntraffic = string.format("%.0f", ntraffic)
                        end
                        f = io.open(fname, "w")
                        if f then
                            f:write(ntotal .. "\n")
                            if (i == datanum) then
                                j = 2
                            else
                                j = 1
                            end
                            for i,v in ipairs(data) do
                                if i > j then
                                    f:write(v .. "\n")
                                end
                            end
                            f:write(ntraffic .. " " ..  times .. "\n")
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
