#!/bin/bash

# Benchmark comparison script with test validation
# Compares current performance against the 'alpha' baseline

set -e

echo "=========================================="
echo "  SudokuCore Benchmark Comparison"
echo "=========================================="
echo ""

# Step 1: Run tests to ensure accuracy
echo "Step 1: Running tests to verify accuracy..."
echo "-------------------------------------------"
if swift test 2>&1 | tee test_output.txt | grep -q "Test Suite.*passed"; then
    echo "✓ All tests passed - accuracy verified"
    echo ""
else
    echo "✗ Tests failed! Cannot compare benchmarks with different accuracy."
    echo "Please fix failing tests before running benchmarks."
    cat test_output.txt | grep -A 5 "FAILED"
    exit 1
fi

# Step 2: Run benchmarks
echo "Step 2: Running benchmarks against alpha baseline..."
echo "-------------------------------------------"
swift package benchmark baseline compare alpha --format jmh > benchmark_raw.txt 2>&1

# Step 3: Extract and format results
echo ""
echo "Step 3: Extracting improvement metrics..."
echo "-------------------------------------------"
echo ""

# Parse the benchmark results
python3 << 'PYTHON_SCRIPT'
import re
import sys

try:
    with open('benchmark_raw.txt', 'r') as f:
        content = f.read()
except FileNotFoundError:
    print("Error: benchmark_raw.txt not found")
    sys.exit(1)

# Extract improvement data
benchmarks = {}
current_benchmark = None

lines = content.split('\n')
for i, line in enumerate(lines):
    # Match benchmark names
    if ' metrics' in line:
        current_benchmark = line.replace(' metrics', '').strip()

    # Match improvement percentage lines for wall clock time
    if '│              Improvement %' in line and current_benchmark:
        # Get the next few lines to find the right improvement row
        parts = [p.strip() for p in line.split('│') if p.strip()]
        if len(parts) >= 4:
            try:
                # p50 is the median value
                p50_value = parts[3]
                if p50_value and p50_value not in ['p50', 'Improvement %']:
                    benchmarks[current_benchmark] = int(p50_value)
            except (ValueError, IndexError):
                pass

# Filter for key benchmarks
key_benchmarks = {
    'Difficulty Calculation': [],
    'Hint Finding': [],
    'Puzzle Generation': []
}

for name, improvement in benchmarks.items():
    if 'DifficultyCalculator' in name:
        key_benchmarks['Difficulty Calculation'].append((name, improvement))
    elif 'HintFinder' in name:
        key_benchmarks['Hint Finding'].append((name, improvement))
    elif 'PuzzleGeneration' in name:
        key_benchmarks['Puzzle Generation'].append((name, improvement))

# Print results
print("╔══════════════════════════════════════════════════════════════════╗")
print("║           Performance Improvements vs Alpha Baseline            ║")
print("╠══════════════════════════════════════════════════════════════════╣")

for category, items in key_benchmarks.items():
    if items:
        print(f"║ {category:64} ║")
        print("╟──────────────────────────────────────────────────────────────────╢")

        for bench_name, improvement in sorted(items):
            # Clean up benchmark name
            clean_name = bench_name.replace('DifficultyCalculator.', '  ').replace('HintFinder.', '  ').replace('PuzzleGeneration.', '  ')

            # Format improvement
            if improvement > 0:
                status = f"✓ {improvement:3d}% faster"
                color = '\033[92m'  # Green
            elif improvement < 0:
                status = f"✗ {abs(improvement):3d}% slower"
                color = '\033[91m'  # Red
            else:
                status = "  no change"
                color = '\033[93m'  # Yellow

            reset = '\033[0m'

            # Print with color
            print(f"║ {clean_name:48} {color}{status:14}{reset} ║")

        print("╟──────────────────────────────────────────────────────────────────╢")

print("╚══════════════════════════════════════════════════════════════════╝")
print()

# Calculate and show overall statistics
all_improvements = list(benchmarks.values())
if all_improvements:
    avg_improvement = sum(all_improvements) / len(all_improvements)
    positive_improvements = [x for x in all_improvements if x > 0]
    negative_improvements = [x for x in all_improvements if x < 0]

    print("Summary Statistics:")
    print(f"  Total benchmarks: {len(all_improvements)}")
    print(f"  Average improvement: {avg_improvement:.1f}%")
    print(f"  Benchmarks faster: {len(positive_improvements)}")
    print(f"  Benchmarks slower: {len(negative_improvements)}")

    if positive_improvements:
        print(f"  Max speedup: {max(positive_improvements)}%")
    if negative_improvements:
        print(f"  Max slowdown: {abs(min(negative_improvements))}%")

PYTHON_SCRIPT

echo ""
echo "=========================================="
echo "  Benchmark comparison complete!"
echo "=========================================="
