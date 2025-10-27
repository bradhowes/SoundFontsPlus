#!/bin/bash

set -x

# There must be an an archive file to use
set -- ${PWD}/coverage_iOS/Test-SoundFontsPlus-*.xcresult
archive="${1}"
[[ -d "${archive}" ]] || exit 1

# Generate the list of source files to process. We only want non-test files.
files="${PWD}/coverage_iOS/files.txt"
if [[ ! -f "${files}" ]]; then
    xcrun xccov view --archive --file-list ${archive} | grep '/Features/Sources/' > "${files}"
fi

# For each source file, get its coverage stats as a JSON object
stats="${PWD}/coverage_iOS/stats.txt"
if [[ ! -f "${stats}" ]]; then
    while read -r line; do
        xcrun xccov view --report --functions-for-file "${line}" --json ${archive} >> "${stats}"
    done < ${files}
fi

# The `$stats` file now has an entry for each file. Use `-s` to treat as one array instead of N arrays, then:
#
# - take first (only) element and get its `functions` attribute
# - for each function object, get the sum of the `coveredLines` and `executableLines` attributes as an array of two values
# - get sums of all of the file coverage sums as an array of two values
# - calculate the coverage percentage by operating on the two values
#
pct=$(jq -s 'map(first|.functions|[map(.coveredLines),map(.executableLines)|add])|[map(.[0]),map(.[1])|add]|.[0]/.[1]*100.0' < "${stats}")
printf "%.1f%%\n" ${pct}
