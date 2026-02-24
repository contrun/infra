#!/usr/bin/env bash
# generate-lock.sh - Record exact installed versions
# Script taken from https://oneuptime.com/blog/post/2026-02-21-how-to-version-control-ansible-galaxy-dependencies/view
set -ueo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
cd "$SCRIPT_DIR" || exit 1

echo "# Auto-generated lock file - do not edit manually" > requirements.lock.yml
echo "# Generated on: $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> requirements.lock.yml
echo "---" >> requirements.lock.yml

# Record installed roles
echo "roles:" >> requirements.lock.yml
ansible-galaxy list 2>/dev/null | grep -vE '^#\s*' | while IFS= read -r line; do
    # Parse "- role_name, version" format
    role_name=$(echo "$line" | sed 's/^- //' | cut -d',' -f1 | tr -d ' ')
    role_version=$(echo "$line" | cut -d',' -f2 | tr -d ' ')
    if [ -n "$role_name" ] && [ -n "$role_version" ]; then
        echo "  - name: ${role_name}" >> requirements.lock.yml
        echo "    version: \"${role_version}\"" >> requirements.lock.yml
    fi
done

# Record installed collections
echo "collections:" >> requirements.lock.yml
ansible-galaxy collection list --format yaml 2>/dev/null | python3 -c "
import sys, yaml
data = yaml.safe_load(sys.stdin)
if data:
    for path, collections in data.items():
        for name, info in collections.items():
            print(f'  - name: {name}')
            print(f'    version: \"{info[\"version\"]}\"')
" >> requirements.lock.yml

echo "Lock file generated: requirements.lock.yml"
