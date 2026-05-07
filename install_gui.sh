#!/bin/bash

# Bash DBMS Installation Script

echo "Bash DBMS Installation"
echo "=========================="

# Check for Zenity (required for GUI)
if ! command -v zenity &> /dev/null; then
    echo "Warning: Zenity is not installed!"
    echo "GUI mode will not be available."
    echo "Install Zenity: sudo apt-get install zenity (Ubuntu/Debian)"
    echo ""
fi

# Make all scripts executable
for script in dbms_lib.sh main.sh gui_dbms.sh sql_parser.sh run_gui.sh; do
    if [ -f "$script" ]; then
        chmod +x "$script"
        echo "✓ Made $script executable"
    fi
done

# Create databases directory
mkdir -p databases
echo "✓ Data directory created"

echo ""
echo "Installation complete!"
echo ""
echo "Usage:"
echo "  CLI Mode:  ./main.sh"
echo "  GUI Mode:  ./gui_dbms.sh (requires Zenity)"
echo "  SQL Mode:  Select option 6 in CLI mode"