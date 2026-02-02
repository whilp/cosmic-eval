#!/usr/bin/env cosmic-lua
--- Summarize eval results from .got files or downloaded artifacts.

local io = require("cosmic.io")
local fs = require("cosmic.fs")
local path = require("cosmo.path")

local passed = 0
local failed = 0
local results = {}

local function add_result(name, got_file)
  local content, err = io.slurp(got_file)
  if not content then
    print("Error reading " .. got_file .. ": " .. (err or "unknown"))
    os.exit(1)
  end

  local code = tonumber(content:match("^%s*(%d+)"))
  if code == 0 then
    passed = passed + 1
    table.insert(results, { name = name, ok = true })
  else
    failed = failed + 1
    table.insert(results, { name = name, ok = false, code = code })
  end
end

-- Check for .got files passed as args
for i = 1, #arg do
  local got_file = arg[i]
  local name = got_file:match("([^/]+)%.got$")
  if name then
    add_result(name, got_file)
  end
end

-- Also check for downloaded artifacts in o/ (from CI)
local ok, dir = pcall(fs.opendir, "o")
if ok then
  for entry in dir:iter() do
    if entry.name:match("^scenario%-") and entry.type == "directory" then
      local exit_file = path.join("o", entry.name, "exit_code.txt")
      local content = io.slurp(exit_file)
      if content then
        add_result(entry.name, exit_file)
      end
    end
  end
end

print("")
print("=== Summary ===")
for _, r in ipairs(results) do
  if r.ok then
    print("✅ " .. r.name)
  else
    print("❌ " .. r.name .. " (exit " .. tostring(r.code) .. ")")
  end
end
print("")
print("Passed: " .. passed .. "  Failed: " .. failed)

if failed > 0 then
  os.exit(1)
end
