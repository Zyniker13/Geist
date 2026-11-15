#!/bin/bash
# check-imports.sh — enforce the determinism rules in Core/Content/AI sources.
# Banned in Core/Content/AI: floating point in rules math, and any nondeterministic source.
# (See _CONVENTIONS.md §4.2 and .swiftlint.yml custom rules — this is the CI-side backstop.)
set -o pipefail

cd "$(dirname "$0")/.."

VIOLATIONS=0

check() {
    local pattern="$1" label="$2"
    local hits
    hits=$(grep -rEn "$pattern" Packages/NMCore/Sources Packages/NMContent/Sources Packages/NMAI/Sources --include='*.swift' | grep -v '^\s*//' | grep -vE '// |///' || true)
    if [ -n "$hits" ]; then
        echo "BANNED ${label}:"
        echo "$hits"
        VIOLATIONS=$((VIOLATIONS + 1))
    fi
}

# Nondeterminism sources (except SeededRNG's own definition files)
check 'SystemRandomNumberGenerator|Int\.random\(|Double\.random\(|UUID\(\)' 'nondeterministic API'
check 'Date\(\)' 'nondeterministic Date()'

# Floating point in rules math (init(_: Double) and doubleValue() are the sanctioned exceptions)
check 'Float' 'Float'

if [ "$VIOLATIONS" -gt 0 ]; then
    echo "check-imports: $VIOLATIONS banned-API category(ies) found"
    exit 1
fi
echo "check-imports: clean"
