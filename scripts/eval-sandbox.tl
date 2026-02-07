#!/usr/bin/env cosmic-lua
--- Run a single eval scenario in a network-restricted Docker container.
---
--- The container can only reach the internet through a Smokescreen proxy
--- that enforces a domain allowlist (config/smokescreen-acl.yaml). Egress
--- that bypasses the proxy is blocked by nftables rules on the host.

local child = require("cosmic.child")
local cio = require("cosmic.io")
local fs = require("cosmic.fs")
local path = require("cosmo.path")

local scenario = arg[1]
if not scenario then
  io.stderr:write("Usage: eval-sandbox.tl <scenario>\n")
  os.exit(1)
end

local root_dir = fs.getcwd()

--- Run a command and return trimmed stdout + exit code.
local function exec(cmd: {string}, stderr_passthrough: boolean): string, integer
  local opts = {}
  if stderr_passthrough then
    opts = {stderr = 2}
  end
  local handle, err = child.spawn(cmd, opts)
  if not handle then
    io.stderr:write("spawn failed: " .. table.concat(cmd, " ") .. ": " .. (err or "") .. "\n")
    return "", 1
  end
  local _, out, code = handle:read()
  out = (out or ""):match("^(.-)%s*$") or ""
  return out, (code as integer) or 1
end

--- Run a command with visible output; error() on failure.
local function must(cmd: {string})
  local handle, err = child.spawn(cmd, {stderr = 2})
  if not handle then
    error("spawn failed: " .. table.concat(cmd, " ") .. ": " .. (err or ""))
  end
  local _, out, code = handle:read()
  if out and out ~= "" then
    io.write(out)
    io.flush()
  end
  if (code or 1) ~= 0 then
    error("failed (exit " .. tostring(code) .. "): " .. table.concat(cmd, " "))
  end
end

--- Cleanup containers, network, and nftables rules.
local function cleanup()
  print("\n=== Cleaning up ===")
  exec({"sudo", "nft", "delete", "table", "inet", "eval_restrict"}, false)
  exec({"docker", "stop", "eval-container", "smokescreen"}, false)
  exec({"docker", "rm", "eval-container", "smokescreen"}, false)
  exec({"docker", "network", "rm", "eval-network"}, false)
end

-- Main logic wrapped in pcall so cleanup always runs
local eval_exit = 1
local ok, main_err = pcall(function()

  -- -------------------------------------------------------------------
  -- Smokescreen proxy
  -- -------------------------------------------------------------------
  print("=== Setting up Smokescreen proxy ===")

  must({"docker", "build", "-t", "smokescreen:local",
    "-f", path.join(root_dir, "config", "Dockerfile.smokescreen"),
    path.join(root_dir, "o")})

  must({"docker", "network", "create", "eval-network"})

  must({"docker", "run", "-d",
    "--name", "smokescreen",
    "--network", "eval-network",
    "-v", path.join(root_dir, "config", "smokescreen.yaml") .. ":/etc/smokescreen/config.yaml:ro",
    "-v", path.join(root_dir, "config", "smokescreen-acl.yaml") .. ":/etc/smokescreen/acl.yaml:ro",
    "-p", "4750:4750",
    "smokescreen:local",
    "--config-file", "/etc/smokescreen/config.yaml",
    "--listen-ip", "0.0.0.0",
    "--listen-port", "4750"})

  -- Wait for proxy to start
  exec({"sleep", "2"}, false)
  exec({"docker", "logs", "smokescreen"}, true)

  local proxy_ip = exec({"docker", "inspect", "-f",
    "{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}", "smokescreen"}, false)
  if proxy_ip == "" then
    error("could not determine Smokescreen IP")
  end
  print("Smokescreen proxy running at " .. proxy_ip .. ":4750")

  -- -------------------------------------------------------------------
  -- Eval container
  -- -------------------------------------------------------------------
  print("\n=== Starting eval container ===")

  must({"docker", "run", "-d",
    "--name", "eval-container",
    "--network", "eval-network",
    "-v", root_dir .. ":/workspace:rw",
    "-w", "/workspace",
    "ubuntu:22.04",
    "sleep", "infinity"})

  local container_ip = exec({"docker", "inspect", "-f",
    "{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}", "eval-container"}, false)
  if container_ip == "" then
    error("could not determine eval container IP")
  end
  print("Eval container IP: " .. container_ip)

  must({"docker", "exec", "eval-container", "bash", "-c",
    "apt-get update -qq && apt-get install -y -qq ca-certificates curl >/dev/null 2>&1 && " ..
    "useradd -m -s /bin/bash eval && chown -R eval:eval /workspace/o"})

  -- -------------------------------------------------------------------
  -- nftables – block all egress except through the proxy
  -- -------------------------------------------------------------------
  print("\n=== Configuring network restrictions ===")

  local nft_rules = string.format([[table inet eval_restrict {
    chain forward {
        type filter hook forward priority 0; policy accept;
        ip saddr %s jump eval_egress
    }
    chain eval_egress {
        ct state established,related accept
        ip daddr %s tcp dport 4750 accept
        log prefix "EVAL_BLOCKED: " drop
    }
}]], container_ip, proxy_ip)

  local nft_file = path.join(os.getenv("TMPDIR") or "/tmp", "eval-nft.conf")
  cio.barf(nft_file, nft_rules)
  must({"sudo", "nft", "-f", nft_file})
  os.remove(nft_file)

  print("Network restrictions active. Running eval...")

  -- -------------------------------------------------------------------
  -- Run the eval
  -- -------------------------------------------------------------------
  local proxy_url = "http://" .. proxy_ip .. ":4750"

  local eval_out, code = exec({"docker", "exec",
    "-u", "eval",
    "-e", "HOME=/home/eval",
    "-e", "CLAUDE_CODE_OAUTH_TOKEN=" .. (os.getenv("CLAUDE_CODE_OAUTH_TOKEN") or ""),
    "-e", "CLAUDE_MODEL=" .. (os.getenv("CLAUDE_MODEL") or "sonnet"),
    "-e", "COSMIC_URL=" .. (os.getenv("COSMIC_URL") or ""),
    "-e", "CLAUDE=/workspace/o/claude",
    "-e", "HTTP_PROXY=" .. proxy_url,
    "-e", "HTTPS_PROXY=" .. proxy_url,
    "-e", "http_proxy=" .. proxy_url,
    "-e", "https_proxy=" .. proxy_url,
    "eval-container", "bash", "-c",
    "export PATH=/workspace/o:$PATH; /workspace/o/cosmic-lua /workspace/scripts/run-eval.tl " .. scenario,
  }, true)

  if eval_out ~= "" then
    io.write(eval_out)
    io.flush()
  end
  eval_exit = code

  -- -------------------------------------------------------------------
  -- Diagnostics
  -- -------------------------------------------------------------------
  print("\n=== Smokescreen proxy logs ===")
  exec({"docker", "logs", "--tail", "50", "smokescreen"}, true)

  print("\n=== Blocked connection attempts ===")
  local dmesg_out = exec({"sudo", "dmesg"}, false)
  local found_blocked = false
  for line in dmesg_out:gmatch("[^\n]+") do
    if line:find("EVAL_BLOCKED", 1, true) then
      print(line)
      found_blocked = true
    end
  end
  if not found_blocked then
    print("No blocked attempts logged")
  end

end)

cleanup()

if not ok then
  io.stderr:write("Error: " .. tostring(main_err) .. "\n")
  os.exit(1)
end

os.exit(eval_exit as integer)
