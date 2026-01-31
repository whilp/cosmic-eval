#!/usr/bin/env cosmic-lua
-- Weather Data Cache Tool - Test Version with Mock API
-- Demonstrates caching functionality without requiring real API key

local sqlite3 = require("cosmo.lsqlite3")

-- Configuration
local CACHE_EXPIRY_SECONDS = 30 * 60  -- 30 minutes
local DB_PATH = "weather_cache.db"

-- Mock weather data for different cities
local MOCK_WEATHER_DATA = {
    London = {
        temperature = 18.5,
        conditions = "Partly cloudy",
        humidity = 65
    },
    Paris = {
        temperature = 20.3,
        conditions = "Sunny",
        humidity = 55
    },
    ["New York"] = {
        temperature = 22.1,
        conditions = "Clear sky",
        humidity = 70
    },
    Tokyo = {
        temperature = 16.8,
        conditions = "Light rain",
        humidity = 80
    }
}

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

-- Mock API fetch (simulates network call)
local function fetch_weather_mock(city, force_error)
    if force_error then
        return nil, "Network error: API unreachable"
    end

    local mock_data = MOCK_WEATHER_DATA[city]
    if not mock_data then
        return nil, "City not found"
    end

    -- Add random variation to temperature to show it's a "new" fetch
    return {
        temperature = mock_data.temperature + (math.random(-2, 2) * 0.1),
        conditions = mock_data.conditions,
        humidity = mock_data.humidity,
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
        io.stderr:write("Usage: weather-test <city> [--force-error]\n")
        io.stderr:write("Test version with mock data. Available cities: London, Paris, New York, Tokyo\n")
        os.exit(1)
    end

    local city = args[1]
    local force_error = (args[2] == "--force-error")

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

    -- Cache is stale or doesn't exist, fetch from mock API
    local weather_data, err = fetch_weather_mock(city, force_error)

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
