#!/usr/bin/env bash
# Integration tests against the live deployed service
# Usage: ./tests/integration_test.sh <SERVICE_URL>

set -e

BASE_URL="${1:-http://localhost:30080}"
PASS=0
FAIL=0

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

assert_eq() {
  local description="$1"
  local expected="$2"
  local actual="$3"
  if [ "$actual" = "$expected" ]; then
    echo -e "${GREEN}PASS${NC}: $description"
    ((PASS++))
  else
    echo -e "${RED}FAIL${NC}: $description (expected '$expected', got '$actual')"
    ((FAIL++))
  fi
}

echo "======================================"
echo " Integration Tests: $BASE_URL"
echo "======================================"

# Test 1: Health check
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/health")
assert_eq "Health check returns 200" "200" "$STATUS"

# Test 2: GET /api/items returns 200
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/api/items")
assert_eq "GET /api/items returns 200" "200" "$STATUS"

# Test 3: POST /api/items creates item
RESPONSE=$(curl -s -X POST "$BASE_URL/api/items" \
  -H "Content-Type: application/json" \
  -d '{"name":"Integration Test Item","value":999}')
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/api/items" \
  -H "Content-Type: application/json" \
  -d '{"name":"Integration Test Item","value":999}')
assert_eq "POST /api/items returns 201" "201" "$STATUS"

# Test 4: GET non-existent item returns 404
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/api/items/99999")
assert_eq "GET non-existent item returns 404" "404" "$STATUS"

# Test 5: POST with missing body returns 400
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/api/items" \
  -H "Content-Type: application/json" \
  -d '{}')
assert_eq "POST with empty body returns 400" "400" "$STATUS"

echo "======================================"
echo " Results: $PASS passed, $FAIL failed"
echo "======================================"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
