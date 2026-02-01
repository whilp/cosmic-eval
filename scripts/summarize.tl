#!/usr/bin/env cosmic-lua
--- Summarize eval results from .got files.

local io = require("cosmic.io")

local passed = 0
local failed = 0
local results = {}

for i = 1, #arg do
  local got_file = arg[i]
  local content, err = io.slurp(got_file)
  if not content then
    print("Error reading " .. got_file .. ": " .. (err or "unknown"))
    os.exit(1)
  end

  local code = tonumber(content:match("^%s*(%d+)"))
  local name = got_file:match("([^/]+)%.got$")

  if code == 0 then
    passed = passed + 1
    table.insert(results, { name = name, ok = true })
  else
    failed = failed + 1
    table.insert(results, { name = name, ok = false, code = code })
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
