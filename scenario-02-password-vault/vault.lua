#!/usr/bin/env ./cosmic-lua
--[[
Password Vault - A secure command-line password manager
Uses Argon2 for master password hashing and SQLite for storage
]]

local argon2 = require("cosmo.argon2")
local sqlite = require("cosmo.lsqlite3")
local unix = require("cosmo.unix")

-- Configuration
local DB_FILE = "vault.db"
local SALT_LENGTH = 16

-- Utility function to read password without echoing
local function read_password(prompt)
    io.write(prompt)
    io.flush()
    os.execute("stty -echo 2>/dev/null")
    local password = io.read()
    os.execute("stty echo 2>/dev/null")
    io.write("\n")
    return password
end

-- Generate a random salt
local function generate_salt()
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
    local salt = {}
    for i = 1, SALT_LENGTH do
        local idx = math.random(1, #chars)
        salt[i] = chars:sub(idx, idx)
    end
    return table.concat(salt)
end

-- Hash password using Argon2
local function hash_password(password, salt)
    return argon2.hash_encoded(password, salt, {})
end

-- Verify password against hash
local function verify_password(hash, password)
    return argon2.verify(hash, password)
end

-- Open database with proper permissions
local function open_database()
    local db = sqlite.open(DB_FILE, sqlite.OPEN_READWRITE + sqlite.OPEN_CREATE)
    if not db then
        error("Failed to open database")
    end

    -- Set file permissions to 0600 (owner read/write only)
    unix.chmod(DB_FILE, 384) -- 384 = 0600 in octal

    return db
end

-- Initialize database schema
local function init_database(db)
    -- Create master password table
    db:exec([[
        CREATE TABLE IF NOT EXISTS master (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            hash TEXT NOT NULL,
            salt TEXT NOT NULL
        )
    ]])

    -- Create credentials table
    db:exec([[
        CREATE TABLE IF NOT EXISTS credentials (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            service TEXT UNIQUE NOT NULL,
            username TEXT NOT NULL,
            password TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
        )
    ]])
end

-- Check if master password is set
local function has_master_password(db)
    local stmt = db:prepare("SELECT COUNT(*) as count FROM master")
    stmt:step()
    local count = stmt:get_value(0)
    stmt:finalize()
    return count > 0
end

-- Set master password
local function set_master_password(db)
    local password = read_password("Create master password: ")
    local confirm = read_password("Confirm master password: ")

    if password ~= confirm then
        error("Passwords do not match")
    end

    if #password < 8 then
        error("Master password must be at least 8 characters")
    end

    local salt = generate_salt()
    local hash = hash_password(password, salt)

    local stmt = db:prepare("INSERT INTO master (id, hash, salt) VALUES (1, ?, ?)")
    stmt:bind_values(hash, salt)
    stmt:step()
    stmt:finalize()

    print("Password vault initialized.")
end

-- Verify master password
local function verify_master_password(db)
    local stmt = db:prepare("SELECT hash FROM master WHERE id = 1")
    stmt:step()
    local stored_hash = stmt:get_value(0)
    stmt:finalize()

    local password = read_password("Enter master password: ")

    if not verify_password(stored_hash, password) then
        error("Incorrect master password")
    end
end

-- Add a new password entry
local function cmd_add(db, service, username)
    if not service or not username then
        print("Usage: vault add <service> <username>")
        os.exit(1)
    end

    -- Check if service already exists
    local stmt = db:prepare("SELECT COUNT(*) FROM credentials WHERE service = ?")
    stmt:bind_values(service)
    stmt:step()
    local count = stmt:get_value(0)
    stmt:finalize()

    if count > 0 then
        error("Service '" .. service .. "' already exists. Use 'update' to change the password.")
    end

    local password = read_password("Enter password for " .. service .. ": ")
    local timestamp = os.time()

    stmt = db:prepare([[
        INSERT INTO credentials (service, username, password, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?)
    ]])
    stmt:bind_values(service, username, password, timestamp, timestamp)
    stmt:step()
    stmt:finalize()

    print("Password stored successfully.")
end

-- Get a password entry
local function cmd_get(db, service)
    if not service then
        print("Usage: vault get <service>")
        os.exit(1)
    end

    local stmt = db:prepare([[
        SELECT username, password FROM credentials WHERE service = ?
    ]])
    stmt:bind_values(service)

    if stmt:step() == sqlite.ROW then
        local username = stmt:get_value(0)
        local password = stmt:get_value(1)
        print("Service: " .. service)
        print("Username: " .. username)
        print("Password: " .. password)
    else
        print("Service '" .. service .. "' not found.")
        os.exit(1)
    end

    stmt:finalize()
end

-- List all services
local function cmd_list(db)
    local stmt = db:prepare("SELECT service, username FROM credentials ORDER BY service")

    print("Stored credentials:")
    local count = 0
    while stmt:step() == sqlite.ROW do
        local service = stmt:get_value(0)
        local username = stmt:get_value(1)
        print("  - " .. service .. " (" .. username .. ")")
        count = count + 1
    end

    if count == 0 then
        print("  (none)")
    end

    stmt:finalize()
end

-- Update a password entry
local function cmd_update(db, service)
    if not service then
        print("Usage: vault update <service>")
        os.exit(1)
    end

    -- Check if service exists
    local stmt = db:prepare("SELECT COUNT(*) FROM credentials WHERE service = ?")
    stmt:bind_values(service)
    stmt:step()
    local count = stmt:get_value(0)
    stmt:finalize()

    if count == 0 then
        error("Service '" .. service .. "' not found.")
    end

    local password = read_password("Enter new password for " .. service .. ": ")
    local timestamp = os.time()

    stmt = db:prepare([[
        UPDATE credentials SET password = ?, updated_at = ? WHERE service = ?
    ]])
    stmt:bind_values(password, timestamp, service)
    stmt:step()
    stmt:finalize()

    print("Password updated successfully.")
end

-- Delete a password entry
local function cmd_delete(db, service)
    if not service then
        print("Usage: vault delete <service>")
        os.exit(1)
    end

    -- Check if service exists
    local stmt = db:prepare("SELECT COUNT(*) FROM credentials WHERE service = ?")
    stmt:bind_values(service)
    stmt:step()
    local count = stmt:get_value(0)
    stmt:finalize()

    if count == 0 then
        error("Service '" .. service .. "' not found.")
    end

    stmt = db:prepare("DELETE FROM credentials WHERE service = ?")
    stmt:bind_values(service)
    stmt:step()
    stmt:finalize()

    print("Password for " .. service .. " deleted.")
end

-- Main function
local function main()
    math.randomseed(os.time())

    local command = arg[1]

    if command == "init" then
        -- Initialize vault
        local db = open_database()
        init_database(db)

        if has_master_password(db) then
            print("Vault already initialized.")
            db:close()
            os.exit(1)
        end

        set_master_password(db)
        db:close()
        return
    end

    -- Check if command is valid before opening database
    local valid_commands = {add = true, get = true, list = true, update = true, delete = true}

    if not valid_commands[command] then
        print("Usage: vault <command> [args]")
        print("")
        print("Commands:")
        print("  init                      Initialize the vault with a master password")
        print("  add <service> <username>  Add a new password entry")
        print("  get <service>             Retrieve a password")
        print("  list                      List all stored services")
        print("  update <service>          Update a password")
        print("  delete <service>          Delete a password entry")
        os.exit(1)
    end

    -- All other commands require an initialized vault
    local db = open_database()
    init_database(db)

    if not has_master_password(db) then
        print("Vault not initialized. Run 'vault init' first.")
        db:close()
        os.exit(1)
    end

    -- Verify master password for all operations
    verify_master_password(db)

    if command == "add" then
        cmd_add(db, arg[2], arg[3])
    elseif command == "get" then
        cmd_get(db, arg[2])
    elseif command == "list" then
        cmd_list(db)
    elseif command == "update" then
        cmd_update(db, arg[2])
    elseif command == "delete" then
        cmd_delete(db, arg[2])
    end

    db:close()
end

-- Run main with error handling
local status, err = pcall(main)
if not status then
    print("Error: " .. tostring(err))
    os.exit(1)
end
