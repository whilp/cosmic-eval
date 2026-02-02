#!/usr/bin/env cosmic-lua
--- List scenario directories as JSON array.

local fs = require("cosmic.fs")
local json = require("cosmic.json")

local only = arg[1]
local scenarios: {string} = {}

local dir = fs.opendir(".")
while true do
  local name = dir:read()
  if not name then break end
  if name:match("^scenario%-") then
    local st = fs.stat(name)
    if st and fs.is_dir(st:mode()) then
      if not only or name:find(only, 1, true) then
        table.insert(scenarios, name)
      end
    end
  end
end
dir:close()

table.sort(scenarios)
io.write("scenarios=")
print((json.encode(scenarios)))
