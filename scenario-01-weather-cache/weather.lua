#!/usr/bin/env cosmic-lua
-- Weather data cache CLI tool
-- Fetches weather from OpenWeatherMap API with SQLite caching

local fetch = require("cosmic.fetch")
local json = require("cosmic.json")
local sqlite = require("cosmic.sqlite")
local getopt = require("cosmo.getopt")
local path = require("cosmo.path")
local unix = require("cosmo.unix")

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
      city TEXT PRIMARY KEY,
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
local function get_cached_weather(db, city)
  local city_lower = city:lower()
  for row in db:query("SELECT * FROM weather WHERE lower(city) = ?", city_lower) do
    return {
      city = row.city,
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
    [[INSERT OR REPLACE INTO weather (city, temperature, conditions, humidity, timestamp)
      VALUES ('%s', %f, '%s', %d, %d)]],
    weather.city:gsub("'", "''"),
    weather.temperature,
    weather.conditions:gsub("'", "''"),
    weather.humidity,
    weather.timestamp
  ))
  return ok, err
end

-- Fetch weather from OpenWeatherMap API
local function fetch_weather(city, api_key)
  local url = string.format(
    "https://api.openweathermap.org/data/2.5/weather?q=%s&appid=%s&units=metric",
    city:gsub(" ", "+"),
    api_key
  )

  local result = fetch.Fetch(url)

  if not result.ok then
    return nil, "network error: " .. (result.error or "unknown")
  end

  if result.status ~= 200 then
    local err_data = json.decode(result.body)
    local message = err_data and err_data.message or "unknown error"
    return nil, string.format("API error (%d): %s", result.status, message)
  end

  local data = json.decode(result.body)
  if not data or not data.main then
    return nil, "invalid API response"
  end

  local conditions = "Unknown"
  if data.weather and data.weather[1] then
    conditions = data.weather[1].description or data.weather[1].main or "Unknown"
    -- Capitalize first letter
    conditions = conditions:sub(1, 1):upper() .. conditions:sub(2)
  end

  return {
    city = data.name or city,
    temperature = data.main.temp,
    conditions = conditions,
    humidity = data.main.humidity,
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
  print("  -k, --api-key KEY    OpenWeatherMap API key (or set WEATHER_API_KEY)")
  print("  -h, --help           Show this help message")
  print("")
  print("Examples:")
  print("  weather London")
  print("  weather --api-key YOUR_KEY \"New York\"")
  print("  WEATHER_API_KEY=YOUR_KEY weather Paris")
end

-- Main function
local function main()
  local parser = getopt.new(arg, "hk:", {
    {"help", "none", "h"},
    {"api-key", "required", "k"},
  })

  local api_key = os.getenv("WEATHER_API_KEY")

  while true do
    local opt, optarg = parser:next()
    if not opt then break end
    if opt == "h" or opt == "help" then
      usage()
      os.exit(0)
    elseif opt == "k" or opt == "api-key" then
      api_key = optarg
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

  if not api_key then
    io.stderr:write("Error: API key required. Set WEATHER_API_KEY or use --api-key\n")
    os.exit(1)
  end

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
  local weather, fetch_err = fetch_weather(city, api_key)

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
