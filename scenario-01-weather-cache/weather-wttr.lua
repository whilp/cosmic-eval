#!/usr/bin/env cosmic-lua
-- Weather Data Cache Tool using wttr.in API
-- Free weather API with no authentication required

local fetch = require("cosmic.fetch")
local sqlite3 = require("cosmo.lsqlite3")

-- Configuration
local CACHE_EXPIRY_SECONDS = 30 * 60  -- 30 minutes
local DB_PATH = "weather_cache.db"

-- Initialize database and create schema if needed
local function init_database()
    local db = sqlite3.open(DB_PATH)
    if not db then
        return nil, "Failed to open database"
    end

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
        city:gsub("'", "''")
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
    local delete_sql = string.format(
        "DELETE FROM weather_cache WHERE city = '%s'",
        city:gsub("'", "''")
    )
    db:exec(delete_sql)

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

-- Parse wttr.in JSON response
local function parse_wttr_json(json_text)
    -- Extract current condition data
    local temp_c = json_text:match('"temp_C"%s*:%s*"([%d%.%-]+)"')
    if not temp_c then
        return nil, "Failed to parse temperature"
    end

    local humidity = json_text:match('"humidity"%s*:%s*"(%d+)"')
    if not humidity then
        return nil, "Failed to parse humidity"
    end

    local weather_desc = json_text:match('"weatherDesc"%s*:%s*%[%s*{%s*"value"%s*:%s*"([^"]+)"')
    if not weather_desc then
        return nil, "Failed to parse weather description"
    end

    return {
        temperature = tonumber(temp_c),
        conditions = weather_desc,
        humidity = tonumber(humidity),
        timestamp = get_timestamp()
    }
end

-- Fetch weather from wttr.in API
local function fetch_weather_from_api(city)
    -- wttr.in provides a simple JSON API
    local url = string.format("https://wttr.in/%s?format=j1", city)

    local result = fetch.Fetch(url, {max_attempts = 3})

    if not result.ok then
        return nil, result.error or "HTTP request failed"
    end

    if result.status ~= 200 then
        if result.status == 404 then
            return nil, "City not found"
        else
            return nil, string.format("API error (status %d)", result.status)
        end
    end

    return parse_wttr_json(result.body)
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
    if #args < 1 then
        io.stderr:write("Usage: weather-wttr <city>\n")
        io.stderr:write("Uses wttr.in free weather API (no API key required)\n")
        os.exit(1)
    end

    local city = args[1]

    -- Initialize database
    local db, err = init_database()
    if not db then
        io.stderr:write("Error: " .. err .. "\n")
        os.exit(1)
    end

    -- Check cache first
    local cached_weather = get_cached_weather(db, city)

    if cached_weather and is_cache_fresh(cached_weather.timestamp) then
        print(format_weather(city, cached_weather, "cache"))
        db:close()
        return
    end

    -- Cache is stale or doesn't exist, fetch from API
    local weather_data, err = fetch_weather_from_api(city)

    if weather_data then
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
