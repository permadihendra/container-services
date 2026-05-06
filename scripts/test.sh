#!/bin/bash

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}========================================"
echo "Running All Tests"
echo -e "========================================${NC}"

PASS=0
FAIL=0

test_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    PASS=$((PASS + 1))
}

test_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    FAIL=$((FAIL + 1))
}

test_endpoint() {
    local name=$1
    local url=$2
    local expected=$3
    
    if response=$(curl -s --max-time 5 "$url" 2>/dev/null); then
        if echo "$response" | grep -q "$expected"; then
            test_pass "$name: $url"
            return 0
        else
            test_fail "$name: unexpected response - $response"
            return 1
        fi
    else
        test_fail "$name: $url - connection failed"
        return 1
    fi
}

echo -e "${YELLOW}=== Container Tests ===${NC}"

containers="flask-a flask-b compose-service-nginx-1 compose-service-postgres-1"
for container in $containers; do
    if nerdctl ps 2>/dev/null | grep -q "$container"; then
        test_pass "Container running: $container"
    else
        test_fail "Container not running: $container"
    fi
done

echo -e "${YELLOW}=== Health Check Tests ===${NC}"
test_endpoint "Flask-A health" "http://localhost:5000/health" "healthy"
test_endpoint "Flask-B health" "http://localhost:5001/health" "healthy"
test_endpoint "NGINX /flask-a/health" "http://localhost:8080/flask-a/health" "healthy"
test_endpoint "NGINX /flask-b/health" "http://localhost:8080/flask-b/health" "healthy"

echo -e "${YELLOW}=== Database Tests ===${NC}"
test_endpoint "Flask-A db-test" "http://localhost:5000/db-test" "PostgreSQL"
test_endpoint "Flask-B db-test" "http://localhost:5001/db-test" "PostgreSQL"
test_endpoint "NGINX /flask-a/db-test" "http://localhost:8080/flask-a/db-test" "PostgreSQL"
test_endpoint "NGINX /flask-b/db-test" "http://localhost:8080/flask-b/db-test" "PostgreSQL"

echo -e "${YELLOW}=== NGINX Routing Tests ===${NC}"
test_endpoint "NGINX root" "http://localhost:8080/" "flask-a"
test_endpoint "NGINX /flask-a" "http://localhost:8080/flask-a/" "flask-a"
test_endpoint "NGINX /flask-b" "http://localhost:8080/flask-b/" "flask-b"

echo -e "${YELLOW}=== Metabase Test ===${NC}"
if response=$(curl -s --max-time 5 "http://localhost:3000" 2>/dev/null); then
    test_pass "Metabase: http://localhost:3000"
else
    test_fail "Metabase: connection failed"
fi

echo -e "\n${YELLOW}========================================"
echo -e "Results: ${GREEN}$PASS passed${NC}, ${RED}$FAIL failed${NC}"
echo -e "========================================${NC}"

if [ $FAIL -gt 0 ]; then
    exit 1
fi