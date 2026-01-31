#!/usr/bin/env cosmic-lua
-- Weather Data Cache Tool
-- Fetches weather data from OpenWeatherMap API and caches it in SQLite

local fetch = require("cosmic.fetch")
local sqlite3 = require("cosmo.lsqlite3")
local unix = require("cosmo.unix")

-- Configuration
local CACHE_EXPIRY_SECONDS = 30 * 60  -- 30 minutes
local DB_PATH = "weather_cache.db"
local API_BASE_URL = "https://api.openweathermap.org/data/2.5/weather"

-- Get API key from environment or command line
local function get_api_key()
    local api_key = os.getenv("OPENWEATHER_API_KEY")
    if not api_key or api_key == "" then
        return nil, "API key not found. Set OPENWEATHER_API_KEY environment variable."
    end
    return api_key
end

-- Initialize database and create schema if needed
local function init_database()
    local db = sqlite3.open(DB_PATH)
    if not db then
        return nil, "Failed to open database"
    end

    -- Create table if it doesn't exist
    local sql = [[
        CREATE TABLE IF NOT EXISTS weather_cache (
            city TEXT PRIMARY KEY,
            temperature REAL,
            conditions TEXT,
            humidity INTEGER,
            timestamp INTEGER
        )
    ]]

    local result = db:exec(sql)
    if result ~= sqlite3.OK then
        return nil, "Failed to create table: " .. db:errmsg()
    end

    return db
end

-- Get current Unix timestamp
local function get_timestamp()
    return os.time()
end

-- Check if cached data is still fresh
local function is_cache_fresh(timestamp)
    local now = get_timestamp()
    return (now - timestamp) < CACHE_EXPIRY_SECONDS
end

-- Get cached weather data for a city
local function get_cached_weather(db, city)
    local sql = string.format(
        "SELECT temperature, conditions, humidity, timestamp FROM weather_cache WHERE city = '%s'",
        city:gsub("'", "''")  -- Escape single quotes
    )

    local weather = nil
    for row in db:nrows(sql) do
        weather = {
            temperature = row.temperature,
            conditions = row.conditions,
            humidity = row.humidity,
            timestamp = row.timestamp
        }
    end

    return weather
end

-- Save weather data to cache
local function save_to_cache(db, city, weather_data)
    -- Delete existing entry if present
    local delete_sql = string.format(
        "DELETE FROM weather_cache WHERE city = '%s'",
        city:gsub("'", "''")
    )
    db:exec(delete_sql)

    -- Insert new data
    local insert_sql = string.format(
        "INSERT INTO weather_cache (city, temperature, conditions, humidity, timestamp) VALUES ('%s', %f, '%s', %d, %d)",
        city:gsub("'", "''"),
        weather_data.temperature,
        weather_data.conditions:gsub("'", "''"),
        weather_data.humidity,
        weather_data.timestamp
    )

    local result = db:exec(insert_sql)
    if result ~= sqlite3.OK then
        return false, "Failed to save to cache: " .. db:errmsg()
    end

    return true
end

-- Fetch weather from API
local function fetch_weather_from_api(city, api_key)
    local url = string.format("%s?q=%s&appid=%s&units=metric", API_BASE_URL, city, api_key)

    local result = fetch.Fetch(url)

    if not result.ok then
        return nil, result.error or "HTTP request failed"
    end

    if result.status ~= 200 then
        if result.status == 404 then
            return nil, "City not found"
        elseif result.status == 401 then
            return nil, "Invalid API key"
        else
            return nil, string.format("API error (status %d)", result.status)
        end
    end

    -- Parse JSON response
    local json_text = result.body

    -- Simple JSON parsing for the fields we need
    -- Extract temperature
    local temp = json_text:match('"temp":([%d%.%-]+)')
    if not temp then
        return nil, "Failed to parse temperature from response"
    end

    -- Extract humidity
    local humidity = json_text:match('"humidity":(%d+)')
    if not humidity then
        return nil, "Failed to parse humidity from response"
    end

    -- Extract weather description
    local description = json_text:match('"description":"([^"]+)"')
    if not description then
        return nil, "Failed to parse weather conditions from response"
    end

    return {
        temperature = tonumber(temp),
        conditions = description,
        humidity = tonumber(humidity),
        timestamp = get_timestamp()
    }
end

-- Format weather data for display
local function format_weather(city, weather_data, source)
    local age_minutes = math.floor((get_timestamp() - weather_data.timestamp) / 60)

    local output = string.format(
        "%s: %.1f°C, %s, Humidity: %d%%",
        city,
        weather_data.temperature,
        weather_data.conditions,
        weather_data.humidity
    )

    if source == "api" then
        output = output .. "\n(Data fetched from API)"
    elseif source == "cache" then
        output = output .. string.format("\n(Cached data from %d minutes ago)", age_minutes)
    elseif source == "stale" then
        output = output .. string.format("\n(WARNING: Using stale cached data from %d minutes ago - API unavailable)", age_minutes)
    end

    return output
end

-- Main function
local function main(args)
    -- Check for city argument
    if #args < 1 then
        io.stderr:write("Usage: weather <city>\n")
        io.stderr:write("Set OPENWEATHER_API_KEY environment variable with your API key\n")
        os.exit(1)
    end

    local city = args[1]

    -- Get API key
    local api_key, err = get_api_key()
    if not api_key then
        io.stderr:write("Error: " .. err .. "\n")
        os.exit(1)
    end

    -- Initialize database
    local db, err = init_database()
    if not db then
        io.stderr:write("Error: " .. err .. "\n")
        os.exit(1)
    end

    -- Check cache first
    local cached_weather = get_cached_weather(db, city)

    if cached_weather and is_cache_fresh(cached_weather.timestamp) then
        -- Cache is fresh, use it
        print(format_weather(city, cached_weather, "cache"))
        db:close()
        return
    end

    -- Cache is stale or doesn't exist, fetch from API
    local weather_data, err = fetch_weather_from_api(city, api_key)

    if weather_data then
        -- Successfully fetched from API
        save_to_cache(db, city, weather_data)
        print(format_weather(city, weather_data, "api"))
    else
        -- API fetch failed, check if we have stale cache to fall back on
        if cached_weather then
            io.stderr:write("Warning: " .. err .. "\n")
            print(format_weather(city, cached_weather, "stale"))
        else
            io.stderr:write("Error: " .. err .. "\n")
            db:close()
            os.exit(1)
        end
    end

    db:close()
end

-- Run main with command line arguments
main(arg)
