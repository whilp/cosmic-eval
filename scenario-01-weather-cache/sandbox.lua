-- Sandbox configuration for scenario-01-weather-cache
-- Used by GitHub Actions workflow to set up nftables network restrictions
return {
  network = {
    enabled = true,
    hosts = {
      "wttr.in",
    },
  },
}
