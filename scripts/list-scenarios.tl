#!/usr/bin/env cosmic-lua
--- List scenario directories as JSON array.

local fs = require("cosmic.fs")
local json = require("cosmic.json")

local only = arg[1]
local scenarios = {}

for entry in fs.opendir("."):iter() do
  if entry.name:match("^scenario%-") and entry.type == "directory" then
    if not only or entry.name:find(only, 1, true) then
      table.insert(scenarios, entry.name)
    end
  end
end

table.sort(scenarios)
print(json.encode(scenarios))
