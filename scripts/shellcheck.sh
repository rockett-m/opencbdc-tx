#!/usr/bin/env bash

# Usage: ./scripts/shellcheck.sh
ROOT="$(cd "$(dirname "$0")"/.. && pwd)"
SHELLCHECK_REPORT="${ROOT}/shellcheck-report.txt"

NUM_CORES=1
if [[ "${OSTYPE}" == "linux-gnu"* ]]; then
    NUM_CORES=$(grep -c ^processor /proc/cpuinfo)
elif [[ "${OSTYPE}" == "darwin"* ]]; then
    NUM_CORES=$(sysctl -n hw.ncpu)
fi

if ! command -v shellcheck &>/dev/null; then
    echo "shellcheck is not installed."
    echo "Run 'sudo ./scripts/install-build-tools.sh' to install shellcheck."
    exit 1
fi

# run shellcheck in parallel on all tracked shell scripts
# checking status of this run will give failure if even a warning is found by default
# info/warnings/errors are treated as unsuccessful, so we need to search the report for
# explicit errors messages to determine if there are any true errors
git ls-files '*.sh' | xargs -n 1 -P "${NUM_CORES}" shellcheck > "${SHELLCHECK_REPORT}"

# if shell check report exists to determine if shellcheck run was successful
if [[ -z "${SHELLCHECK_REPORT}" ]]; then
    echo "Shellcheck report ${SHELLCHECK_REPORT} not found. Exiting..."
    exit 1
else
    echo "Shellcheck report: ${SHELLCHECK_REPORT}"
    if [[ ! -s "${SHELLCHECK_REPORT}" ]]; then
        echo "Shellcheck report is empty."
        echo "Either there are no info/warning/error messages across all shell scripts,"
        echo "or shellcheck failed to run successfully."
        exit 0
    fi
fi

# view non-empty shellcheck report, includes info, warnings, errors
if [[ "$#" -eq 1 && "$1" == "view" ]]; then
    echo "Shellcheck report: ${SHELLCHECK_REPORT}"
    cat "${SHELLCHECK_REPORT}"
fi

# detect if fatal errors are in shellcheck report
echo "Checking for fatal errors in shellcheck report..."
if ! grep "(error):" "${SHELLCHECK_REPORT}"; then
    echo "Shellcheck found no fatal errors in report: ${SHELLCHECK_REPORT}"
    echo "Shellcheck passed."
    exit 0
else
    echo "Shellcheck found fatal errors in report: ${SHELLCHECK_REPORT}"
    echo "Shellcheck failed."
    exit 1
fi
