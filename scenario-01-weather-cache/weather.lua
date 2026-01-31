#!/usr/bin/env cosmic-lua

local cosmo = require("cosmo")
local sqlite = require("cosmo.lsqlite3")
local path = require("cosmo.path")

local CACHE_DURATION_SECONDS = 30 * 60 -- 30 minutes

local function get_db_path()
    local home = os.getenv("HOME") or "/tmp"
    return path.join(home, ".weather_cache.db")
end

local function init_db(db)
    local sql = [[
        CREATE TABLE IF NOT EXISTS weather (
            city TEXT PRIMARY KEY,
            temperature REAL,
            conditions TEXT,
            humidity INTEGER,
            timestamp INTEGER
        )
    ]]
    local result = db:exec(sql)
    if result ~= sqlite.OK then
        error("Failed to create table: " .. db:errmsg())
    end
end

local function open_db()
    local db_path = get_db_path()
    local db, err = sqlite.open(db_path)
    if not db then
        error("Failed to open database: " .. tostring(err))
    end
    init_db(db)
    return db
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

local function save_weather(db, city, data)
    local normalized = normalize_city(city)
    local stmt = db:prepare("INSERT OR REPLACE INTO weather (city, temperature, conditions, humidity, timestamp) VALUES (?, ?, ?, ?, ?)")
    if not stmt then
        return false, db:errmsg()
    end
    stmt:bind_values(normalized, data.temperature, data.conditions, data.humidity, data.timestamp)
    local result = stmt:step()
    stmt:finalize()
    return result == sqlite.DONE, nil
end

local function fetch_weather_from_api(city)
    local encoded_city = cosmo.EscapePath(city)
    local url = "https://wttr.in/" .. encoded_city .. "?format=j1"

    local status, headers, body = cosmo.Fetch(url)

    if not status or status ~= 200 then
        return nil, "API request failed with status: " .. tostring(status)
    end

    if not body or body == "" then
        return nil, "Empty response from API"
    end

    local ok, json = pcall(cosmo.DecodeJson, body)
    if not ok then
        return nil, "Failed to parse JSON: " .. tostring(json)
    end

    if not json.current_condition or #json.current_condition == 0 then
        return nil, "Invalid city name or no weather data available"
    end

    local current = json.current_condition[1]

    local conditions = "Unknown"
    if current.weatherDesc and #current.weatherDesc > 0 then
        conditions = current.weatherDesc[1].value or "Unknown"
    end

    return {
        temperature = tonumber(current.temp_C) or 0,
        conditions = conditions,
        humidity = tonumber(current.humidity) or 0,
        timestamp = os.time()
    }, nil
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

local function get_weather(city)
    local db = open_db()

    local cached, _ = get_cached_weather(db, city)

    if cached and not is_cache_stale(cached.timestamp) then
        db:close()
        return format_weather(city, cached, format_cache_age(cached.timestamp))
    end

    local fresh, fetch_err = fetch_weather_from_api(city)

    if fresh then
        save_weather(db, city, fresh)
        db:close()
        return format_weather(city, fresh, "Data fetched from API")
    end

    if cached then
        db:close()
        local warning = string.format("Warning: Could not refresh data (%s). Using stale cache.", fetch_err or "unknown error")
        return format_weather(city, cached, format_cache_age(cached.timestamp)) .. "\n" .. warning
    end

    db:close()
    return nil, fetch_err or "Failed to fetch weather data"
end

local function main()
    if #arg < 1 then
        io.stderr:write("Usage: weather <city>\n")
        io.stderr:write("Example: weather London\n")
        os.exit(1)
    end

    local city = arg[1]

    local result, err = get_weather(city)
    if result then
        print(result)
    else
        io.stderr:write("Error: " .. (err or "Unknown error") .. "\n")
        os.exit(1)
    end
end

main()
