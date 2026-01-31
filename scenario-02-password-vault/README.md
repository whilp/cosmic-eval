# Scenario 2: Password Vault

## Goal

Build a command-line password manager that securely stores passwords using cryptographic hashing and maintains them in a local database.

## Requirements

### Core Functionality

1. **Master Password Protection**
   - Prompt for a master password on startup
   - Hash the master password using a strong algorithm (Argon2, bcrypt, or PBKDF2)
   - Store the hash in the database for verification
   - On subsequent runs, verify the entered master password against the stored hash

2. **Password Storage**
   - Store account credentials with the following fields:
     - `service` (text): Name of the service (e.g., "github.com", "email")
     - `username` (text): Username or email for the service
     - `password` (text): The actual password (encrypted or hashed as appropriate)
     - `created_at` (integer): Unix timestamp when entry was created
     - `updated_at` (integer): Unix timestamp when entry was last modified

3. **SQLite Database**
   - Create tables for master password hash and stored credentials
   - Handle database initialization on first run
   - Ensure database file permissions are restrictive (readable only by owner)

4. **Command-Line Interface**
   - `add <service> <username>`: Add a new password entry (prompt for password securely)
   - `get <service>`: Retrieve and display the password for a service
   - `list`: List all stored services (without showing passwords)
   - `update <service>`: Update the password for an existing service
   - `delete <service>`: Remove a service from the vault

### Security Requirements

- **Password Input**: Never echo passwords to the terminal when entering them
- **Master Password**: Use a strong key derivation function (Argon2 recommended, or bcrypt/PBKDF2)
- **Password Storage**: Passwords should be encrypted using a key derived from the master password, OR stored in plaintext if encryption is too complex (document this limitation)
- **Database Permissions**: Set file permissions to 0600 (owner read/write only)

### Example Usage

```bash
# First run - initialize vault
$ ./vault init
Create master password: ****
Confirm master password: ****
Password vault initialized.

# Add a password
$ ./vault add github.com alice
Enter password for github.com: ****
Password stored successfully.

# List all services
$ ./vault list
Stored credentials:
  - github.com (alice)
  - email.com (alice@example.com)

# Retrieve a password
$ ./vault get github.com
Service: github.com
Username: alice
Password: mySecretP@ss123

# Update a password
$ ./vault update github.com
Enter new password for github.com: ****
Password updated successfully.

# Delete an entry
$ ./vault delete github.com
Password for github.com deleted.
```

## Testing Criteria

Your implementation should demonstrate:

1. Secure password hashing (using Argon2, bcrypt, or PBKDF2)
2. Master password verification on each run
3. SQLite database with proper schema
4. All CRUD operations (Create, Read, Update, Delete) working
5. Password input without echoing to terminal
6. Proper file permissions on the database file
7. Error handling for:
   - Incorrect master password
   - Duplicate service entries
   - Non-existent service queries
   - Database corruption or missing files

## Notes

- For simplicity, you may store passwords in plaintext if implementing proper encryption is too complex - just document this as a limitation
- Focus on the master password hashing being cryptographically secure
- The vault should be usable by a single user on a single machine (no multi-user support needed)
- Consider using environment variables for testing to avoid interactive prompts
