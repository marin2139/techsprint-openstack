#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== TechSprint Cleanup ==="
echo ""
echo "This will destroy ALL provisioned resources."
read -p "Are you sure? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 0
fi

cd "$PROJECT_DIR/terraform"
terraform destroy -auto-approve

echo ""
echo "=== CLEANUP DONE ==="
