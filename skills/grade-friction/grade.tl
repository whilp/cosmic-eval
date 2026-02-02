#!/usr/bin/env cosmic-lua
--- Compute objective metrics from cosmic-eval conversation.jsonl
--- Usage: ./lua grade.tl <conversation.jsonl> [lua-files...]

local json = require("cosmic.json")
local cio = require("cosmic.io")

local record EscapeHatch
  file: string
  line: integer
  pattern: string
  description: string
  code: string
end

local record TokenUsage
  input_tokens: integer
  output_tokens: integer
  cache_creation_input_tokens: integer
  cache_read_input_tokens: integer
end

local record Metrics
  total_messages: integer
  assistant_turns: integer
  user_messages: integer
  tool_calls: integer
  tools_used: {string}
  tool_counts: {string: integer}
  first_timestamp: string
  last_timestamp: string
  duration_seconds: integer
  escape_hatches: {EscapeHatch}
  -- Token usage
  api_calls: integer
  input_tokens: integer
  output_tokens: integer
  cache_creation_tokens: integer
  cache_read_tokens: integer
end

local record ContentBlock
  type: string
  name: string
end

local record MessageUsage
  input_tokens: integer
  output_tokens: integer
  cache_creation_input_tokens: integer
  cache_read_input_tokens: integer
end

local record Message
  content: {ContentBlock}
  usage: MessageUsage
end

local record ConversationEntry
  type: string
  timestamp: string
  message: Message
end

local function usage()
  print("Usage: grade.tl <conversation.jsonl> [lua-files...]")
  print("")
  print("Analyzes eval artifacts and outputs metrics as JSON.")
  print("")
  print("Examples:")
  print("  grade.tl conversation.jsonl")
  print("  grade.tl conversation.jsonl *.lua")
  os.exit(1)
end

local conversation_path = arg[1]
if not conversation_path then
  usage()
end

-- Collect lua files from remaining args
local lua_files: {string} = {}
for i = 2, #arg do
  table.insert(lua_files, arg[i])
end

-- Parse conversation.jsonl
local content, err = cio.slurp(conversation_path)
if not content then
  io.stderr:write("Error reading " .. conversation_path .. ": " .. (err or "unknown") .. "\n")
  os.exit(1)
end

-- Parse each line as JSON
local messages: {ConversationEntry} = {}
for line in content:gmatch("[^\n]+") do
  local ok, msg = pcall(json.decode, line) as (boolean, ConversationEntry)
  if ok and msg then
    table.insert(messages, msg)
  end
end

-- Initialize metrics
local metrics: Metrics = {
  total_messages = 0,
  assistant_turns = 0,
  user_messages = 0,
  tool_calls = 0,
  tools_used = {},
  tool_counts = {},
  first_timestamp = nil,
  last_timestamp = nil,
  duration_seconds = nil,
  escape_hatches = {},
  -- Token usage
  api_calls = 0,
  input_tokens = 0,
  output_tokens = 0,
  cache_creation_tokens = 0,
  cache_read_tokens = 0,
}

local tools_seen: {string: boolean} = {}

for _, msg in ipairs(messages) do
  metrics.total_messages = metrics.total_messages + 1

  -- Track timestamps
  if msg.timestamp then
    if not metrics.first_timestamp then
      metrics.first_timestamp = msg.timestamp
    end
    metrics.last_timestamp = msg.timestamp
  end

  -- Count message types
  if msg.type == "assistant" then
    metrics.assistant_turns = metrics.assistant_turns + 1

    -- Count tool uses
    if msg.message and msg.message.content then
      for _, block in ipairs(msg.message.content) do
        if block.type == "tool_use" then
          metrics.tool_calls = metrics.tool_calls + 1
          local name = block.name or "unknown"
          metrics.tool_counts[name] = (metrics.tool_counts[name] or 0) + 1
          tools_seen[name] = true
        end
      end
    end

    -- Sum token usage
    if msg.message and msg.message.usage then
      local u = msg.message.usage
      metrics.api_calls = metrics.api_calls + 1
      metrics.input_tokens = metrics.input_tokens + (u.input_tokens or 0)
      metrics.output_tokens = metrics.output_tokens + (u.output_tokens or 0)
      metrics.cache_creation_tokens = metrics.cache_creation_tokens + (u.cache_creation_input_tokens or 0)
      metrics.cache_read_tokens = metrics.cache_read_tokens + (u.cache_read_input_tokens or 0)
    end
  elseif msg.type == "user" then
    metrics.user_messages = metrics.user_messages + 1
  end
end

-- Calculate duration
if metrics.first_timestamp and metrics.last_timestamp then
  -- Parse ISO timestamps: 2026-02-02T04:03:06.230Z
  local function parse_iso(ts: string): integer
    local y, mo, d, h, mi, s = ts:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):([%d%.]+)")
    if y then
      return os.time({year=tonumber(y) as integer, month=tonumber(mo) as integer,
                      day=tonumber(d) as integer, hour=tonumber(h) as integer,
                      min=tonumber(mi) as integer, sec=math.floor(tonumber(s) as number) as integer})
    end
    return 0
  end

  local start_time = parse_iso(metrics.first_timestamp)
  local end_time = parse_iso(metrics.last_timestamp)
  if start_time > 0 and end_time > 0 then
    metrics.duration_seconds = end_time - start_time
  end
end

-- Convert tools_seen to sorted list
for tool, _ in pairs(tools_seen) do
  table.insert(metrics.tools_used, tool)
end
table.sort(metrics.tools_used)

-- Escape hatch patterns to detect
local record EscapePattern
  pattern: string
  description: string
end

local escape_patterns: {EscapePattern} = {
  {pattern = "unix%.", description = "raw unix module"},
  {pattern = "os%.execute", description = "shell execution"},
  {pattern = "io%.popen", description = "shell pipe"},
  {pattern = "lsqlite3", description = "raw lsqlite3 (prefer cosmic.sqlite)"},
}

-- Scan lua files for escape hatches
for _, filepath in ipairs(lua_files) do
  local lua_content, lua_err = cio.slurp(filepath)
  if lua_content then
    local line_num = 0
    for line in lua_content:gmatch("[^\n]+") do
      line_num = line_num + 1
      for _, pat in ipairs(escape_patterns) do
        if line:match(pat.pattern) then
          local hatch: EscapeHatch = {
            file = filepath,
            line = line_num,
            pattern = pat.pattern,
            description = pat.description,
            code = line:match("^%s*(.-)%s*$"),  -- trim
          }
          table.insert(metrics.escape_hatches, hatch)
        end
      end
    end
  end
end

-- Output as JSON
local output = json.encode(metrics)
print(output)
