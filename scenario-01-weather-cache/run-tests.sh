#!/bin/bash
# Comprehensive test suite for weather cache tool

set -e

WEATHER_TEST="./cosmic-lua weather-test.lua"

echo "=================================="
echo "Weather Cache Tool - Test Suite"
echo "=================================="
echo ""

# Clean up
rm -f weather_cache.db

echo "1. Testing first request (should fetch from API)..."
$WEATHER_TEST London
echo ""

sleep 1

echo "2. Testing cached request (should use cache)..."
$WEATHER_TEST London
echo ""

echo "3. Testing different city (should fetch from API)..."
$WEATHER_TEST Paris
echo ""

echo "4. Testing invalid city (should show error)..."
if $WEATHER_TEST InvalidCity 2>&1; then
    echo "ERROR: Should have failed for invalid city"
    exit 1
else
    echo "Correctly rejected invalid city"
fi
echo ""

echo "5. Testing multiple cities in cache..."
$WEATHER_TEST "New York"
$WEATHER_TEST Tokyo
echo ""

sleep 1

echo "6. Testing all cached cities are retrievable..."
$WEATHER_TEST London
$WEATHER_TEST Paris
$WEATHER_TEST "New York"
$WEATHER_TEST Tokyo
echo ""

echo "7. Simulating stale cache (31 minutes old)..."
./cosmic-lua -e "
local sqlite3 = require('cosmo.lsqlite3')
local db = sqlite3.open('weather_cache.db')
local old_timestamp = os.time() - (31 * 60)
db:exec(string.format('UPDATE weather_cache SET timestamp = %d WHERE city = \"London\"', old_timestamp))
db:close()
"
echo ""

echo "8. Testing stale cache with API available (should fetch fresh)..."
$WEATHER_TEST London
echo ""

echo "9. Simulating stale cache again for network error test..."
./cosmic-lua -e "
local sqlite3 = require('cosmo.lsqlite3')
local db = sqlite3.open('weather_cache.db')
local old_timestamp = os.time() - (31 * 60)
db:exec(string.format('UPDATE weather_cache SET timestamp = %d WHERE city = \"London\"', old_timestamp))
db:close()
"
echo ""

echo "10. Testing graceful degradation (stale cache + network error)..."
if $WEATHER_TEST London --force-error 2>&1; then
    echo "Successfully used stale cache as fallback"
else
    echo "ERROR: Should have used stale cache"
    exit 1
fi
echo ""

echo "11. Testing network error with no cache (should fail)..."
if $WEATHER_TEST Berlin --force-error 2>&1; then
    echo "ERROR: Should have failed with no cache available"
    exit 1
else
    echo "Correctly failed with no cache available"
fi
echo ""

echo "=================================="
echo "All tests passed!"
echo "=================================="
echo ""
echo "Database contents:"
./cosmic-lua -e "
local sqlite3 = require('cosmo.lsqlite3')
local db = sqlite3.open('weather_cache.db')
print('')
print('City              | Temp  | Conditions      | Humidity | Age (min)')
print('------------------|-------|-----------------|----------|----------')
for row in db:nrows('SELECT * FROM weather_cache ORDER BY city') do
    local age = math.floor((os.time() - row.timestamp) / 60)
    print(string.format('%-17s | %5.1f | %-15s | %8d | %d',
        row.city, row.temperature, row.conditions, row.humidity, age))
end
db:close()
"
