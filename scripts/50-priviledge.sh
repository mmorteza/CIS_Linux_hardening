#!/usr/bin/env bash

UID_MIN=$(awk '/^\s*UID_MIN/ {print $2}' /etc/login.defs)
AUDIT_RULE_FILE="/etc/audit/rules.d/50-privileged.rules"

NEW_DATA=()

# Find all mounted partitions (nodev types), except noexec/nosuid ones
for PARTITION in $(findmnt -n -l -k -it "$(awk '/nodev/ { print $2 }' /proc/filesystems | paste -sd,)" \
    | grep -Pv "noexec|nosuid" | awk '{print $1}'); do

    # Find SUID/SGID executables
    readarray -t DATA < <(
        find "$PARTITION" -xdev -perm /6000 -type f \
            | awk -v UID_MIN="$UID_MIN" \
              '{print "-a always,exit -F path=" $1 " -F perm=x -F auid>=" UID_MIN " -F auid!=4294967295 -k privileged"}'
    )

    # Append to NEW_DATA
    for ENTRY in "${DATA[@]}"; do
        NEW_DATA+=("$ENTRY")
    done
done

# Read existing rules if file exists
if [[ -f "$AUDIT_RULE_FILE" ]]; then
    readarray -t OLD_DATA < "$AUDIT_RULE_FILE"
else
    OLD_DATA=()
fi

# Combine and deduplicate
COMBINED_DATA=( "${OLD_DATA[@]}" "${NEW_DATA[@]}" )

printf '%s\n' "${COMBINED_DATA[@]}" | sort -u > "$AUDIT_RULE_FILE"
