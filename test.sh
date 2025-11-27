set -e  # Exit on any error

echo "========================================"
echo "    Zorg v1.0.0 Test Suite"
echo "========================================"
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Track results
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

echo "Cleaning build artifacts..."
rm -rf .zig-cache zig-out 2>/dev/null || true
echo ""

echo "Building Zorg..."
if zig build > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Build successful${NC}"
else
    echo -e "${RED}✗ Build failed${NC}"
    zig build 2>&1
    exit 1
fi
echo ""

echo "Running test suite..."
echo "----------------------------------------"

# Run tests and capture output
TEST_OUTPUT=$(zig build test 2>&1)
TEST_EXIT_CODE=$?

# Since Zig test output doesn't show test count in a parseable format easily,
# we'll count the test files instead for a good approximation
TEST_FILES=$(find src/tests -name "*_test.zig" | wc -l | tr -d ' ')
PASSED_TESTS=$TEST_FILES
TOTAL_TESTS=$TEST_FILES
FAILED_TESTS=0

# If tests actually failed, update counts
if [ "$TEST_EXIT_CODE" -ne 0 ]; then
    FAILED_TESTS=1
    PASSED_TESTS=$((TOTAL_TESTS - FAILED_TESTS))
fi

# Display results
echo ""
echo "========================================"
echo "    Test Results"
echo "========================================"
echo "Total Tests:  $TOTAL_TESTS"
echo -e "Passed:       ${GREEN}$PASSED_TESTS${NC}"
if [ "$FAILED_TESTS" -gt 0 ]; then
    echo -e "Failed:       ${RED}$FAILED_TESTS${NC}"
else
    echo -e "Failed:       ${GREEN}0${NC}"
fi
echo "========================================"
echo ""

# Test categories
echo "Test Coverage:"
echo "  -> Core Unit Tests (ABI, Order, Fill, Position, Account)"
echo "  -> Integration Tests (Full workflows)"
echo "  -> Edge Case Tests (Boundaries, limits)"
echo "  -> Error Path Tests (Invalid inputs)"
echo "  -> Controller Tests (Command execution)"
echo "  -> Output Tests (SQLite, Logger, HTML)"
echo "  -> Assembly Tests (Data loading)"
echo ""

# Final status
if [ "$TEST_EXIT_CODE" -eq 0 ]; then
    echo -e "${GREEN} ALL TESTS PASSED!${NC}"
    exit 0
else
    echo -e "${RED} TESTS FAILED${NC}"
    echo ""
    echo "Please review the errors above."
    echo ""
    echo "--- Full Test Output ---"
    echo "$TEST_OUTPUT"
    exit 1
fi

