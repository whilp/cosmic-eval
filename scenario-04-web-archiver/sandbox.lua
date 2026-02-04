-- Sandbox configuration for scenario-04-web-archiver
-- Used by GitHub Actions workflow to set up nftables network restrictions
return {
  network = {
    enabled = true,
    hosts = {
      "example.com",
      "www.example.com",
      "example.org",
      "httpbin.org",
      "www.google.com",
    },
  },
}
