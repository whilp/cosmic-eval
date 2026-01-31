# Scenario 1: Weather Data Cache

## Goal

Build a command-line tool that fetches current weather data from a public API and caches it locally to minimize API calls and improve response time.

## Requirements

### Core Functionality

1. **HTTP API Client**
   - Fetch weather data from OpenWeatherMap API (or similar free weather API)
   - Handle HTTP errors gracefully (network failures, rate limits, invalid responses)
   - Parse JSON responses

2. **SQLite Caching**
   - Store weather data in a SQLite database with the following schema:
     - `city` (text): City name
     - `temperature` (real): Temperature in Celsius
     - `conditions` (text): Weather conditions (e.g., "sunny", "cloudy")
     - `humidity` (integer): Humidity percentage
     - `timestamp` (integer): Unix timestamp when data was fetched
   - Implement cache expiration: data older than 30 minutes is considered stale

3. **Command-Line Interface**
   - Accept a city name as argument
   - Display current weather for the requested city
   - Show whether the data came from cache or was freshly fetched

### Behavior

- **First request for a city**: Fetch from API, store in database, display results
- **Subsequent requests (within 30 minutes)**: Return cached data without making API call
- **Stale cache (>30 minutes old)**: Fetch fresh data, update database, display results
- **Network failures**: If API is unreachable but cache exists (even if stale), return cached data with a warning

### Example Usage

```bash
# First request - fetches from API
$ ./weather "London"
London: 18°C, Partly cloudy, Humidity: 65%
(Data fetched from API)

# Second request within 30 minutes - uses cache
$ ./weather "London"
London: 18°C, Partly cloudy, Humidity: 65%
(Cached data from 5 minutes ago)

# Request after 30 minutes - fetches fresh data
$ ./weather "London"
London: 19°C, Sunny, Humidity: 60%
(Data fetched from API)
```

## Testing Criteria

Your implementation should demonstrate:

1. Successful HTTP requests to a real weather API
2. Proper JSON parsing of API responses
3. SQLite database creation and schema setup
4. INSERT and SELECT queries working correctly
5. Cache expiration logic functioning (stale data is refreshed)
6. Error handling for network failures
7. Error handling for invalid city names
8. Graceful degradation (serving stale cache when API is unavailable)

## Notes

- You'll need to sign up for a free API key from a weather service (OpenWeatherMap, WeatherAPI, etc.)
- The API key should be configurable (environment variable or command-line argument)
- Focus on correctness and robustness rather than feature completeness
