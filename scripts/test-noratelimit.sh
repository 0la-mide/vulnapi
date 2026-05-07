#!/bin/bash

BASE_URL="http://127.0.0.1:8000/api"

echo "=== NO RATE LIMITING DEMONSTRATION ==="
echo "Testing 50 rapid login attempts with wrong passwords..."
echo ""

START_TIME=$(date +%s%N)

for i in {1..50}; do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/login" \
      -H "Content-Type: application/json" \
      -d '{"email":"test@test.com","password":"wrongpassword"}')
    
    if [ $((i % 10)) -eq 0 ]; then
        echo "Attempt $i: HTTP $HTTP_CODE"
    fi
done

END_TIME=$(date +%s%N)
DURATION=$(( ($END_TIME - $START_TIME) / 1000000 ))

echo ""
echo "All 50 attempts completed in ${DURATION}ms"
echo "Notice: No rate limiting! No CAPTCHA! No account lockout!"
echo "An attacker could brute-force passwords at thousands of attempts per second."