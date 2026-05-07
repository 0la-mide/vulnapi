#!/bin/bash

# Find and kill the PHP development server
echo "Stopping VulnAPI Server..."

# On Windows (Git Bash/Cygwin)
taskkill //F //IM php.exe 2>/dev/null

# On Linux/Mac
# pkill -f "php artisan serve"

echo "Server stopped (if it was running)"