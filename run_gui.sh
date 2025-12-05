#!/bin/bash

# Quick launcher for Bash DBMS GUI

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Launching Bash DBMS GUI...${NC}"
echo ""

# Check if Zenity is installed
if ! command -v zenity &> /dev/null; then
    echo -e "${RED}❌ Zenity is not installed!${NC}"
    echo ""
    echo "Would you like to install it now? (y/n)"
    read -r answer
    if [[ $answer =~ ^[Yy]$ ]]; then
        echo "Installing Zenity..."
        if [ -f "install_gui.sh" ]; then
            ./install_gui.sh
        else
            echo "Please run ./install_gui.sh first"
            exit 1
        fi
    else
        echo "Please install Zenity to use the GUI."
        exit 1
    fi
fi

# Check if main script exists
if [ ! -f "gui_dbms.sh" ]; then
    echo -e "${RED}❌ GUI script not found!${NC}"
    echo "Please ensure gui_dbms.sh is in the current directory."
    exit 1
fi

# Make sure it's executable
if [ ! -x "gui_dbms.sh" ]; then
    chmod +x gui_dbms.sh
fi

# Clear terminal and show splash
clear
echo ""
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo -e "${BLUE}         Bash DBMS GUI${NC}"
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo ""
echo "Starting the graphical interface..."
echo ""

# Add a small delay for better UX
sleep 1

# Launch the GUI
./gui_dbms.sh

# After GUI closes
echo ""
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo -e "Thank you for using Bash DBMS GUI!"
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo ""