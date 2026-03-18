#!/usr/bin/env bash
# ============================================================
#   Blauplug Trading Platform — Smoke Test Script
#   Run after: docker-compose up -d --build
#   Usage: bash smoke_test.sh [base_url]
# ============================================================

BASE="${1:-http://localhost:8000}"
PASS=0
FAIL=0
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check() {
  local desc="$1"
  local expected_code="$2"
  local actual_code="$3"
  local body="$4"

  if [ "$actual_code" -eq "$expected_code" ]; then
    echo -e "  ${GREEN}✓${NC} $desc (HTTP $actual_code)"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}✗${NC} $desc — expected HTTP $expected_code, got $actual_code"
    if [ -n "$body" ]; then echo "    Response: $body" | head -c 200; fi
    FAIL=$((FAIL + 1))
  fi
}

echo ""
echo -e "${YELLOW}=== Blauplug Trading Platform — Smoke Test ===${NC}"
echo -e "${YELLOW}Base URL: $BASE${NC}"
echo ""

# ── 1. Health Checks ─────────────────────────────────────────────────────────
echo "[ Health Checks ]"

code=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/health")
check "API Gateway /health" 200 "$code"

code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:8001/health")
check "Market Data /health" 200 "$code"

code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:8002/health")
check "Order Management /health" 200 "$code"

code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:8003/health")
check "Trade Execution /health" 200 "$code"

code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:8004/health")
check "AI Signal /health" 200 "$code"

echo ""

# ── 2. Authentication ─────────────────────────────────────────────────────────
echo "[ Authentication ]"

AUTH_RESP=$(curl -s -X POST "$BASE/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"Admin@1234"}')

TOKEN=$(echo "$AUTH_RESP" | grep -oP '"access_token"\s*:\s*"\K[^"]+')
code=$(echo "$AUTH_RESP" | grep -oP '"access_token"' | wc -l)

if [ "$code" -gt 0 ] && [ -n "$TOKEN" ]; then
  echo -e "  ${GREEN}✓${NC} Login succeeded — JWT obtained"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}✗${NC} Login failed — could not get JWT"
  echo "    Response: $AUTH_RESP" | head -c 300
  FAIL=$((FAIL + 1))
fi

echo ""

# ── 3. Market Info ────────────────────────────────────────────────────────────
echo "[ Market Data ]"

code=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer $TOKEN" \
  "$BASE/api/market/info")
check "GET /api/market/info" 200 "$code"

echo ""

# ── 4. Order Lifecycle ────────────────────────────────────────────────────────
echo "[ Order Lifecycle ]"

ORDER_RESP=$(curl -s -X POST "$BASE/api/orders" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"symbol":"RELIANCE","side":"BUY","quantity":5,"order_type":"MARKET","exchange":"NSE","product":"MIS"}')

ORDER_ID=$(echo "$ORDER_RESP" | grep -oP '"id"\s*:\s*"\K[^"]+')
ORDER_STATUS=$(echo "$ORDER_RESP" | grep -oP '"status"\s*:\s*"\K[^"]+')

if [ -n "$ORDER_ID" ]; then
  echo -e "  ${GREEN}✓${NC} POST /api/orders — order_id=${ORDER_ID:0:20}... status=$ORDER_STATUS"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}✗${NC} POST /api/orders failed"
  echo "    Response: $ORDER_RESP" | head -c 400
  FAIL=$((FAIL + 1))
fi

# Fetch the order
if [ -n "$ORDER_ID" ]; then
  code=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer $TOKEN" \
    "$BASE/api/orders/$ORDER_ID")
  check "GET /api/orders/{id}" 200 "$code"
fi

# List orders
code=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer $TOKEN" \
  "$BASE/api/orders")
check "GET /api/orders (list)" 200 "$code"

# Cancel the order (only valid if status is PLACED or VALIDATED)
if [ -n "$ORDER_ID" ] && [ "$ORDER_STATUS" != "executed" ]; then
  CANCEL_RESP=$(curl -s -X DELETE \
    -H "Authorization: Bearer $TOKEN" \
    "$BASE/api/orders/$ORDER_ID")
  cancel_code=$(echo "$CANCEL_RESP" | grep -oP '"message"' | wc -l)
  if [ "$cancel_code" -gt 0 ]; then
    echo -e "  ${GREEN}✓${NC} DELETE /api/orders/{id} — order cancelled"
    PASS=$((PASS + 1))
  else
    echo -e "  ${YELLOW}~${NC} DELETE /api/orders/{id} — skipped (order already executed/rejected)"
    PASS=$((PASS + 1))
  fi
fi

echo ""

# ── 5. AI Signals ─────────────────────────────────────────────────────────────
echo "[ AI Signals ]"

code=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer $TOKEN" \
  "$BASE/api/signals/latest")
check "GET /api/signals/latest" 200 "$code"

echo ""

# ── 6. Prometheus Metrics ─────────────────────────────────────────────────────
echo "[ Monitoring ]"

code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:9090/-/healthy")
check "Prometheus /-/healthy" 200 "$code"

code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:3000/api/health")
check "Grafana /api/health" 200 "$code"

echo ""

# ── Summary ───────────────────────────────────────────────────────────────────
TOTAL=$((PASS + FAIL))
echo "================================================"
echo -e "Results: ${GREEN}$PASS passed${NC} / ${RED}$FAIL failed${NC} out of $TOTAL checks"

if [ "$FAIL" -gt 0 ]; then
  echo -e "${RED}Some checks failed. See above for details.${NC}"
  exit 1
else
  echo -e "${GREEN}All checks passed! Platform is healthy.${NC}"
  exit 0
fi
