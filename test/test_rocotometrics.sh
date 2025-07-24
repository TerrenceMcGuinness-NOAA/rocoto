#!/bin/bash

# Test script for rocotometrics utility
# This script tests various functionality of the rocotometrics tool

echo "========================================"
echo "Testing rocotometrics utility"
echo "========================================"
echo

ROCOTO_DIR="/home/tmcguinness/GITHUB/COPILOT/rocoto"
METRICS_CMD="${ROCOTO_DIR}/bin/rocotometrics"

# Check if the utility exists and is executable
if [[ ! -x "$METRICS_CMD" ]]; then
    echo "ERROR: rocotometrics not found or not executable at $METRICS_CMD"
    exit 1
fi

echo "✓ rocotometrics found and executable"

# Test 1: Help functionality
echo
echo "Test 1: Help functionality"
echo "----------------------------------------"
if $METRICS_CMD -h > /dev/null 2>&1; then
    echo "✓ Help option works"
else
    echo "✗ Help option failed"
fi

# Test 2: Basic summary (default)
echo
echo "Test 2: Basic summary"
echo "----------------------------------------"
if $METRICS_CMD > /tmp/rocotometrics_test.out 2>&1; then
    echo "✓ Basic summary works"
    echo "   Found $(grep -c "processes" /tmp/rocotometrics_test.out) daemon process types"
else
    echo "✗ Basic summary failed"
    cat /tmp/rocotometrics_test.out
fi

# Test 3: User statistics
echo
echo "Test 3: User statistics (-u)"
echo "----------------------------------------" 
if $METRICS_CMD -u > /tmp/rocotometrics_user.out 2>&1; then
    echo "✓ User statistics work"
    if grep -q "USER" /tmp/rocotometrics_user.out; then
        echo "   User stats format is correct"
    fi
else
    echo "✗ User statistics failed"
    cat /tmp/rocotometrics_user.out
fi

# Test 4: System statistics
echo
echo "Test 4: System statistics (-s)"
echo "----------------------------------------"
if $METRICS_CMD -s > /tmp/rocotometrics_system.out 2>&1; then
    echo "✓ System statistics work"
    if grep -q "System Load" /tmp/rocotometrics_system.out; then
        echo "   System load information present"
    fi
    if grep -q "System Memory" /tmp/rocotometrics_system.out; then
        echo "   System memory information present"
    fi
else
    echo "✗ System statistics failed"
    cat /tmp/rocotometrics_system.out
fi

# Test 5: Thread information
echo
echo "Test 5: Thread information (-t)"
echo "----------------------------------------"
if $METRICS_CMD -t > /tmp/rocotometrics_threads.out 2>&1; then
    echo "✓ Thread information works"
    if grep -q "THREADS" /tmp/rocotometrics_threads.out; then
        echo "   Thread header format is correct"
    fi
else
    echo "✗ Thread information failed"
    cat /tmp/rocotometrics_threads.out
fi

# Test 6: Process information
echo
echo "Test 6: Process information (-p)"
echo "----------------------------------------"
if $METRICS_CMD -p > /tmp/rocotometrics_processes.out 2>&1; then
    echo "✓ Process information works"
    if grep -q "PID" /tmp/rocotometrics_processes.out; then
        echo "   Process header format is correct"
    fi
else
    echo "✗ Process information failed"
    cat /tmp/rocotometrics_processes.out
fi

# Test 7: Combined options
echo
echo "Test 7: Combined options (-u -s)"
echo "----------------------------------------"
if $METRICS_CMD -u -s > /tmp/rocotometrics_combined.out 2>&1; then
    echo "✓ Combined options work"
    if grep -q "Per-User" /tmp/rocotometrics_combined.out && grep -q "System-Wide" /tmp/rocotometrics_combined.out; then
        echo "   Both user and system statistics present"
    fi
else
    echo "✗ Combined options failed"
    cat /tmp/rocotometrics_combined.out
fi

# Test 8: Verbose mode
echo
echo "Test 8: Verbose mode (-v 2)"
echo "----------------------------------------"
if $METRICS_CMD -v 2 > /tmp/rocotometrics_verbose.out 2>&1; then
    echo "✓ Verbose mode works"
else
    echo "✗ Verbose mode failed"
    cat /tmp/rocotometrics_verbose.out
fi

# Test 9: Invalid option handling
echo
echo "Test 9: Invalid option handling"
echo "----------------------------------------"
if $METRICS_CMD --invalid-option > /tmp/rocotometrics_invalid.out 2>&1; then
    echo "✗ Invalid option should have failed"
else
    echo "✓ Invalid option properly rejected"
fi

# Summary
echo
echo "========================================"
echo "Test Summary"
echo "========================================"
echo

# Count running daemons
DAEMON_COUNT=$(ps aux | grep -E "rocoto(bq|db|io)server" | grep -v grep | wc -l)
echo "Current Rocoto daemons running: $DAEMON_COUNT"

if [[ $DAEMON_COUNT -gt 0 ]]; then
    echo "✓ Daemons are active, metrics are meaningful"
    echo
    echo "Sample output:"
    echo "----------------------------------------"
    $METRICS_CMD | head -15
else
    echo "⚠ No daemons currently running, but utility functions correctly"
fi

# Cleanup
rm -f /tmp/rocotometrics_*.out

echo
echo "Testing complete!"
