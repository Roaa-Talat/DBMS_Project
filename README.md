# Bash Shell Script DBMS

A complete Database Management System (DBMS) implemented in pure Bash shell script. This project provides both a command-line interface (CLI) and a graphical user interface (GUI) for managing databases, tables, and data, with support for SQL-like commands.

## Features

- **Multiple Interfaces**:
  - Command-line interface (CLI) for terminal users
  - Graphical user interface (GUI) using Zenity
  - SQL mode for executing SQL-like commands

- **Database Operations**:
  - Create, list, and drop databases
  - Connect to databases

- **Table Operations**:
  - Create tables with custom columns
  - Define column types (string, int)
  - Set primary keys with uniqueness constraints
  - List and drop tables

- **Data Operations**:
  - Insert records with validation
  - Select all data or specific columns
  - Filter data with WHERE conditions
  - Update records with validation
  - Delete records by condition or all data

- **Data Integrity**:
  - Primary key uniqueness enforcement
  - Data type validation (integer, string)
  - Name validation (alphanumeric and underscores)

## Project Structure

```
DBMS_Project/
├── dbms_lib.sh          # Shared library with core DBMS functions
├── main.sh              # CLI interface
├── gui_dbms.sh          # GUI interface (requires Zenity)
├── sql_parser.sh        # SQL command parser
├── install_gui.sh       # GUI installation script
├── run_gui.sh           # Quick GUI launcher
├── README.md            # This file
└── databases/           # Data directory (created automatically)
```

## Architecture

The project follows a modular architecture with a shared library pattern:

- **dbms_lib.sh**: Contains all core database operations as reusable functions
- **main.sh**: CLI wrapper that provides interactive menus and calls library functions
- **gui_dbms.sh**: GUI wrapper using Zenity dialogs
- **sql_parser.sh**: SQL command parser that translates SQL syntax to library function calls

This design eliminates code duplication and makes the system maintainable.

## Installation

### Prerequisites

- Bash shell (version 4.0 or higher recommended)
- Standard Unix utilities: `awk`, `grep`, `sed`, `cut`, `column`
- For GUI mode: Zenity (install with package manager)

### Installing Zenity (for GUI mode)

**Ubuntu/Debian:**
```bash
sudo apt-get install zenity
```

**Fedora/RHEL:**
```bash
sudo dnf install zenity
```

**Arch Linux:**
```bash
sudo pacman -S zenity
```

### Setup

1. Clone or download the project
2. Make scripts executable:
```bash
chmod +x main.sh gui_dbms.sh sql_parser.sh dbms_lib.sh install_gui.sh run_gui.sh
```

3. Run the installation script (optional, for GUI):
```bash
./install_gui.sh
```

## Usage

### CLI Mode

Run the main script:
```bash
./main.sh
```

**Main Menu Options:**
1. Create Database - Create a new database
2. List Databases - Show all databases
3. Connect to Database - Connect to a database to manage tables
4. Drop Database - Delete a database
5. Exit - Exit the program
6. SQL Mode - Enter SQL command mode

**Table Menu Options (after connecting):**
1. Create Table - Create a new table with columns
2. List Tables - Show all tables in the database
3. Drop Table - Delete a table
4. Insert into Table - Add new records
5. Select From Table - Query data (all, specific columns, with conditions)
6. Delete From Table - Remove records
7. Update Table - Modify existing records
8. Back to Main Menu - Return to main menu

### GUI Mode

Run the GUI launcher:
```bash
./run_gui.sh
```

Or directly:
```bash
./gui_dbms.sh
```

The GUI provides the same functionality through dialog windows with a modern, user-friendly interface.

### SQL Mode

From the main menu, select option 6 to enter SQL mode.

**Supported SQL Commands:**

```sql
-- Database operations
CREATE DATABASE database_name;
USE database_name;
DROP DATABASE database_name;

-- Table operations
CREATE TABLE table_name (column1 TYPE, column2 TYPE PRIMARY KEY, ...);
DROP TABLE table_name;

-- Data operations
INSERT INTO table_name VALUES (value1, 'value2', ...);
SELECT * FROM table_name;
SELECT col1, col2 FROM table_name;
SELECT * FROM table_name WHERE column = value;
SELECT col1, col2 FROM table_name WHERE column = value;
UPDATE table_name SET column = value WHERE column = condition;
DELETE FROM table_name WHERE column = value;
```

**Data Types:**
- `string` - Text data
- `int` - Integer numbers

**Example Session:**
```sql
SQL> CREATE DATABASE mydb;
Database 'mydb' created successfully!
SQL> USE mydb;
Database changed to 'mydb'
mydb SQL> CREATE TABLE users (id INT PRIMARY KEY, name STRING, age INT);
Table 'users' created successfully!
mydb SQL> INSERT INTO users VALUES (1, 'John', 25);
1 row inserted successfully!
mydb SQL> SELECT * FROM users;
id|name|age
1|John|25
Total records: 1
mydb SQL> exit
Exiting SQL mode...
```

## Data Storage

Data is stored in plain text files in the `databases/` directory:

```
databases/
└── database_name/
    ├── table_name_meta    # Table metadata (columns, types, primary keys)
    └── table_name_data    # Table data (pipe-separated values)
```

**Metadata File Format:**
```
col_count:3
col1_name:id
col1_type:int
col1_primary:1
col2_name:name
col2_type:string
col2_primary:0
col3_name:age
col3_type:int
col3_primary:0
```

**Data File Format:**
```
1|John|25
2|Jane|30
3|Bob|35
```

## Naming Conventions

- **Database names**: Must start with a letter or underscore, followed by letters, numbers, or underscores
- **Table names**: Same rules as database names
- **Column names**: Same rules as database names

Valid examples: `mydb`, `test_db`, `db1`, `_private`
Invalid examples: `123db`, `my-db`, `my.db`

## Error Handling

The system provides clear error messages for common issues:

- Duplicate database/table names
- Invalid names (doesn't follow naming conventions)
- Primary key violations
- Data type mismatches
- Empty primary key values
- Non-existent databases/tables


## Troubleshooting

**"dbms_lib.sh not found" error:**
- Ensure all scripts are in the same directory
- Check file permissions

**"SQL parser not available" warning:**
- Ensure `sql_parser.sh` exists and is executable
- SQL mode will be disabled if the parser is missing

**GUI not working:**
- Install Zenity: `sudo apt-get install zenity` (Ubuntu/Debian)
- Check if Zenity is installed: `which zenity`

**Permission denied errors:**
- Make scripts executable: `chmod +x *.sh`
- Ensure write permissions for the `databases/` directory
