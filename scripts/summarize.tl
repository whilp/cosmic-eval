#!/usr/bin/env cosmic-lua
--- Summarize eval results from .got files or downloaded artifacts.

local cio = require("cosmic.io")
local fs = require("cosmic.fs")
local path = require("cosmo.path")

local record Result
  name: string
  ok: boolean
  code: number
end

local passed = 0
local failed = 0
local results: {Result} = {}

local function add_result(name: string, got_file: string)
  local content, err = cio.slurp(got_file)
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
local success, dir = pcall(fs.opendir, "o")
if success then
  while true do
    local name = dir:read()
    if not name then break end
    if name:match("^scenario%-") then
      local subpath = path.join("o", name)
      local st = fs.stat(subpath)
      if st and fs.is_dir(st:mode()) then
        local exit_file = path.join(subpath, "exit_code.txt")
        local content = cio.slurp(exit_file)
        if content then
          add_result(name, exit_file)
        end
      end
    end
  end
  dir:close()
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
