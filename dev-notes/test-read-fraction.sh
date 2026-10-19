#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
htslib_include=$1
htslib_library=$2
samtools=$3
native_bin=$4
tmp=$(mktemp -d "${TMPDIR:-/tmp}/rglimpse-read-fraction.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
cat > "$tmp/test.cpp" <<'CPP'
#include "phase/src/io/genotype_bam_caller.cpp"
#include <cstdlib>
int main(int argc, char **argv) {
    if (argc != 4) return 2;
    aux_t aux{};
    aux.read_fraction = std::stod(argv[2]);
    aux.read_fraction_seed = std::stoul(argv[3]);
    if (aux.read_fraction_seed) {
        std::srand(aux.read_fraction_seed);
        aux.read_fraction_seed = std::rand();
    }
    aux.keep_orphan = true;
    aux.fp = sam_open(argv[1], "r");
    if (!aux.fp) return 3;
    aux.hdr = sam_hdr_read(aux.fp);
    if (!aux.hdr) return 4;
    bam1_t *record = bam_init1();
    int status;
    while ((status = read_bam(&aux, record)) >= 0)
        std::cout << bam_get_qname(record) << '\t' << record->core.flag << '\n';
    bam_destroy1(record);
    sam_hdr_destroy(aux.hdr);
    sam_close(aux.fp);
    return status < -1 ? 5 : 0;
}
CPP
"${CXX:-c++}" -std=c++17 -O1 -DSIMDE_NO_NATIVE -ffunction-sections -fdata-sections \
    -Wno-psabi -Wno-ignored-attributes -I. -Iphase/src -Icommon/src \
    -Ithird_party/simde -I"$htslib_include" "$tmp/test.cpp" \
    -Wl,--gc-sections "$htslib_library" -Wl,-rpath,"$(dirname "$htslib_library")" \
    -o "$tmp/test"
fixture=RGlimpse2/inst/tinytest/tiny-read-fraction
for seed in 0 17; do
    for fraction in 0.25 0.5 0.75; do
        "$samtools" view --subsample "$fraction" --subsample-seed "$seed" "$fixture/pairs.bam" | cut -f1,2 > "$tmp/expected"
        "$tmp/test" "$fixture/pairs.bam" "$fraction" "$seed" > "$tmp/observed"
        cmp "$tmp/expected" "$tmp/observed"
    done
done
"$tmp/test" "$fixture/pairs.bam" 0 0 > "$tmp/empty"
test ! -s "$tmp/empty"
"$samtools" view "$fixture/pairs.bam" | cut -f1,2 > "$tmp/expected"
"$tmp/test" "$fixture/pairs.bam" 1 17 > "$tmp/observed"
cmp "$tmp/expected" "$tmp/observed"
reference=RGlimpse2/inst/tinytest/tiny-symbolic-bam
"$native_bin/GLIMPSE2_split_reference" --reference "$reference/reference.bcf" \
    --map "$reference/genetic-map.txt" --input-region chr11:900-1600 \
    --output-region chr11:1000-1490 --output "$tmp/reference" --seed 8101 \
    > "$tmp/split.log"
"$samtools" view --no-PG -b --subsample 0.5 --subsample-seed 17 \
    -o "$tmp/expected.bam" "$fixture/pairs.bam"
"$samtools" index "$tmp/expected.bam"
common=(--reference "$tmp/reference_chr11_900_1600.bin" --ind-name target \
    --seed 8102 --threads 1 --burnin 1 --main 3 --pbwt-depth 2 --Kinit 4 --Kpbwt 4)
"$native_bin/GLIMPSE2_phase" "${common[@]}" --bam-file "$fixture/pairs.bam" \
    --read-fraction 0.5 --read-fraction-seed 17 --output "$tmp/actual.vcf" \
    > "$tmp/actual.log"
"$native_bin/GLIMPSE2_phase" "${common[@]}" --bam-file "$tmp/expected.bam" \
    --output "$tmp/expected.vcf" > "$tmp/expected.log"
grep -v '^##fileDate=' "$tmp/actual.vcf" > "$tmp/actual-records.vcf"
grep -v '^##fileDate=' "$tmp/expected.vcf" > "$tmp/expected-records.vcf"
cmp "$tmp/actual-records.vcf" "$tmp/expected-records.vcf"
printf 'PASS read-loader identities, mates, nesting, endpoints and native phase seed\n'
