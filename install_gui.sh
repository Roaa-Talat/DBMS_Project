#!/bin/bash

# Bash DBMS GUI Minimal Installer

echo "Bash DBMS GUI Installation"
echo "=========================="

# Check for Zenity (REQUIRED)
if ! command -v zenity &> /dev/null; then
    echo "Error: Zenity is not installed!"
    echo "Please install Zenity first."
    exit 1
fi

# Make main GUI executable
if [ -f "gui_dbms.sh" ]; then
    chmod +x gui_dbms.sh
    echo "✓ GUI script prepared"
else
    echo "Error: gui_dbms.sh not found!"
    exit 1
fi

# Create databases directory
mkdir -p databases
echo "✓ Data directory created"

# Check for SQL parser 
if [ -f "sql_parser.sh" ]; then
    chmod +x sql_parser.sh
    echo "✓ SQL mode enabled"
fi

echo ""
echo "Installation complete!"
echo "Run: ./gui_dbms.sh"