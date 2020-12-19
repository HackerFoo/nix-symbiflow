#!/usr/bin/env bash

OUTPUT="$1"

if [ -z "$OUTPUT" ]; then
    echo "$0 [output file name]"
    exit 1
fi

URL_BASE=https://storage.googleapis.com/symbiflow-arch-defs-gha/
declare -A PACKAGE HASH URL
PACKAGE[benchmarks]=symbiflow-benchmarks-latest
PACKAGE[toolchain]=symbiflow-toolchain-latest
PACKAGE[arch_50t]=symbiflow-xc7a50t_test-latest
PACKAGE[arch_100t]=symbiflow-xc7a100t_test-latest
PACKAGE[arch_200t]=symbiflow-xc7a200t_test-latest

for data in "${!PACKAGE[@]}"; do
    URL[$data]=`curl -s ${URL_BASE}${PACKAGE[$data]}`
    HASH[$data]=`nix-prefetch-url --name $data "${URL[$data]}"`
done

echo "# Generated with: $0 $@" > "$OUTPUT"
echo "{ fetchurl }:" >> "$OUTPUT"
echo "{" >> "$OUTPUT"
for data in "${!PACKAGE[@]}"; do
    echo "  $data = fetchurl {" >> "$OUTPUT"
    echo "    name = \"$data\";" >> "$OUTPUT"
    echo "    url = \"${URL[$data]}\";" >> "$OUTPUT"
    echo "    sha256 = \"${HASH[$data]}\";" >> "$OUTPUT"
    echo "  };" >> "$OUTPUT"
done
echo "}" >> "$OUTPUT"

echo "Output written to: ${OUTPUT}"

