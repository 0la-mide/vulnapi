#!/bin/bash

echo "Starting VulnAPI Server in background..."
cd C:/Users/Olamide/Desktop/vulnapi
php artisan serve > /dev/null 2>&1 &
SERVER_PID=$!

# Wait for server to start
sleep 3

# Run all vulnerability tests
bash test-all-vulns.sh

# Ask if user wants to stop server
read -p "Stop the server? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    kill $SERVER_PID
    echo "Server stopped."
fi