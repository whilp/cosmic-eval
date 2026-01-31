#!/usr/bin/env cosmic-lua

-- Test script that simulates API failure with stale cache fallback
local cosmo = require("cosmo")
local sqlite = require("cosmo.lsqlite3")
local path = require("cosmo.path")

local CACHE_DURATION_SECONDS = 30 * 60

local function get_db_path()
    local home = os.getenv("HOME") or "/tmp"
    return path.join(home, ".weather_cache.db")
end

local function normalize_city(city)
    return city:lower():gsub("^%s+", ""):gsub("%s+$", "")
end

local function get_cached_weather(db, city)
    local normalized = normalize_city(city)
    local stmt = db:prepare("SELECT temperature, conditions, humidity, timestamp FROM weather WHERE city = ?")
    if not stmt then
        return nil, nil
    end
    stmt:bind_values(normalized)
    local result = stmt:step()
    if result == sqlite.ROW then
        local data = {
            temperature = stmt:get_value(0),
            conditions = stmt:get_value(1),
            humidity = stmt:get_value(2),
            timestamp = stmt:get_value(3)
        }
        stmt:finalize()
        return data, nil
    end
    stmt:finalize()
    return nil, nil
end

local function format_weather(city, data, source_msg)
    local temp_str = string.format("%d°C", math.floor(data.temperature + 0.5))
    return string.format("%s: %s, %s, Humidity: %d%%\n(%s)",
        city, temp_str, data.conditions, data.humidity, source_msg)
end

local function format_cache_age(timestamp)
    local age_seconds = os.time() - timestamp
    if age_seconds < 60 then
        return string.format("Cached data from %d seconds ago", age_seconds)
    else
        local minutes = math.floor(age_seconds / 60)
        return string.format("Cached data from %d minute%s ago", minutes, minutes == 1 and "" or "s")
    end
end

local function is_cache_stale(timestamp)
    return (os.time() - timestamp) > CACHE_DURATION_SECONDS
end

-- Simulate API failure
local function fetch_weather_from_api_FAIL(city)
    return nil, "Simulated network failure"
end

local function test_fallback()
    local city = "London"
    local db = sqlite.open(get_db_path())

    local cached = get_cached_weather(db, city)
    if not cached then
        print("ERROR: No cached data found for London. Run 'weather London' first.")
        db:close()
        return
    end

    print("Testing graceful degradation...")
    print("Cache status: " .. (is_cache_stale(cached.timestamp) and "STALE" or "FRESH"))
    print("Cache age: " .. math.floor((os.time() - cached.timestamp) / 60) .. " minutes")
    print()

    -- Simulate what happens when API fails but we have stale cache
    local fresh, fetch_err = fetch_weather_from_api_FAIL(city)

    if fresh then
        print("API returned fresh data (unexpected)")
    else
        if cached then
            local warning = string.format("Warning: Could not refresh data (%s). Using stale cache.", fetch_err or "unknown error")
            print(format_weather(city, cached, format_cache_age(cached.timestamp)))
            print(warning)
        else
            print("ERROR: " .. fetch_err)
        end
    end

    db:close()
end

test_fallback()
