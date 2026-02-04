-- Sandbox configuration for scenario-03-download-mirror
-- Used by GitHub Actions workflow to set up nftables network restrictions
return {
  network = {
    enabled = true,
    hosts = {
      "httpbin.org",
      "www.google.com",
      "example.com",
      "releases.ubuntu.com",
    },
  },
}
