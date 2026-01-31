#!/usr/bin/env cosmic-lua
-- Weather data cache CLI tool
-- Fetches weather from wttr.in API with SQLite caching

local fetch = require("cosmic.fetch")
local json = require("cosmic.json")
local sqlite = require("cosmic.sqlite")
local getopt = require("cosmo.getopt")
local path = require("cosmo.path")

local CACHE_TTL_SECONDS = 30 * 60  -- 30 minutes

-- Get database path in user's home or current directory
local function get_db_path()
  local home = os.getenv("HOME") or "."
  return path.join(home, ".weather_cache.db")
end

-- Initialize database schema
local function init_db(db)
  local ok, err = db:exec([[
    CREATE TABLE IF NOT EXISTS weather (
      query_city TEXT PRIMARY KEY,
      display_city TEXT,
      temperature REAL,
      conditions TEXT,
      humidity INTEGER,
      timestamp INTEGER
    )
  ]])
  if not ok then
    return nil, "failed to create table: " .. (err or "unknown error")
  end
  return true
end

-- Check if cached data is fresh (within TTL)
local function is_cache_fresh(timestamp)
  local now = os.time()
  return (now - timestamp) < CACHE_TTL_SECONDS
end

-- Format time ago string
local function time_ago(timestamp)
  local diff = os.time() - timestamp
  if diff < 60 then
    return string.format("%d seconds ago", diff)
  elseif diff < 3600 then
    return string.format("%d minutes ago", math.floor(diff / 60))
  else
    return string.format("%d hours ago", math.floor(diff / 3600))
  end
end

-- Get cached weather for a city
local function get_cached_weather(db, query_city)
  local city_lower = query_city:lower()
  for row in db:query("SELECT * FROM weather WHERE lower(query_city) = ?", city_lower) do
    return {
      query_city = row.query_city,
      city = row.display_city,
      temperature = row.temperature,
      conditions = row.conditions,
      humidity = row.humidity,
      timestamp = row.timestamp
    }
  end
  return nil
end

-- Save weather to cache
local function save_weather(db, weather)
  local ok, err = db:exec(string.format(
    [[INSERT OR REPLACE INTO weather (query_city, display_city, temperature, conditions, humidity, timestamp)
      VALUES ('%s', '%s', %f, '%s', %d, %d)]],
    weather.query_city:gsub("'", "''"),
    weather.city:gsub("'", "''"),
    weather.temperature,
    weather.conditions:gsub("'", "''"),
    weather.humidity,
    weather.timestamp
  ))
  return ok, err
end

-- Fetch weather from wttr.in API
local function fetch_weather(query_city)
  -- URL encode the city name
  local encoded_city = query_city:gsub(" ", "+"):gsub(",", "%%2C")
  local url = string.format("https://wttr.in/%s?format=j1", encoded_city)

  local result = fetch.Fetch(url)

  if not result.ok then
    return nil, "network error: " .. (result.error or "unknown")
  end

  if result.status ~= 200 then
    return nil, string.format("API error (%d)", result.status)
  end

  local ok, data = pcall(json.decode, result.body)
  if not ok or not data then
    return nil, "invalid API response: failed to parse JSON"
  end

  if not data.current_condition or not data.current_condition[1] then
    return nil, "invalid API response: missing weather data"
  end

  local current = data.current_condition[1]

  -- Get location name from response for display
  local display_city = query_city
  if data.nearest_area and data.nearest_area[1] then
    local area = data.nearest_area[1]
    if area.areaName and area.areaName[1] then
      display_city = area.areaName[1].value
    end
  end

  local conditions = "Unknown"
  if current.weatherDesc and current.weatherDesc[1] then
    conditions = current.weatherDesc[1].value or "Unknown"
  end

  local temp = tonumber(current.temp_C) or 0
  local humidity = tonumber(current.humidity) or 0

  return {
    query_city = query_city,
    city = display_city,
    temperature = temp,
    conditions = conditions,
    humidity = humidity,
    timestamp = os.time()
  }
end

-- Display weather data
local function display_weather(weather, source)
  print(string.format("%s: %.0f°C, %s, Humidity: %d%%",
    weather.city,
    weather.temperature,
    weather.conditions,
    weather.humidity
  ))
  print(string.format("(%s)", source))
end

-- Print usage
local function usage()
  print("Usage: weather [options] <city>")
  print("")
  print("Options:")
  print("  -h, --help    Show this help message")
  print("")
  print("Examples:")
  print("  weather London")
  print("  weather \"New York\"")
  print("  weather Paris")
end

-- Main function
local function main()
  local parser = getopt.new(arg, "h", {
    {"help", "none", "h"},
  })

  while true do
    local opt, optarg = parser:next()
    if not opt then break end
    if opt == "h" or opt == "help" then
      usage()
      os.exit(0)
    elseif opt == "?" then
      io.stderr:write("Unknown option: " .. (optarg or "") .. "\n")
      usage()
      os.exit(1)
    end
  end

  local remaining = parser:remaining()
  if #remaining == 0 then
    io.stderr:write("Error: City name required\n\n")
    usage()
    os.exit(1)
  end

  local city = remaining[1]

  -- Open database
  local db, db_err = sqlite.open(get_db_path())
  if not db then
    io.stderr:write("Error opening database: " .. (db_err or "unknown") .. "\n")
    os.exit(1)
  end

  -- Initialize schema
  local init_ok, init_err = init_db(db)
  if not init_ok then
    io.stderr:write("Error initializing database: " .. init_err .. "\n")
    db:close()
    os.exit(1)
  end

  -- Check cache first
  local cached = get_cached_weather(db, city)

  if cached and is_cache_fresh(cached.timestamp) then
    -- Cache hit and fresh
    display_weather(cached, "Cached data from " .. time_ago(cached.timestamp))
    db:close()
    return
  end

  -- Try to fetch fresh data
  local weather, fetch_err = fetch_weather(city)

  if weather then
    -- Successfully fetched, update cache
    local save_ok, save_err = save_weather(db, weather)
    if not save_ok then
      io.stderr:write("Warning: Failed to save to cache: " .. (save_err or "unknown") .. "\n")
    end
    display_weather(weather, "Data fetched from API")
  elseif cached then
    -- Network failed but we have stale cache
    io.stderr:write("Warning: " .. fetch_err .. "\n")
    io.stderr:write("Returning stale cached data.\n")
    display_weather(cached, "Stale cached data from " .. time_ago(cached.timestamp))
  else
    -- No cache and network failed
    io.stderr:write("Error: " .. fetch_err .. "\n")
    db:close()
    os.exit(1)
  end

  db:close()
end

main()
