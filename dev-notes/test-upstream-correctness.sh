#!/usr/bin/env bash
# Requires a C++17 compiler, HTSlib and Boost development libraries.
set -euo pipefail
cd "$(dirname "$0")/.."
tmp=$(mktemp -d "${TMPDIR:-/tmp}/rglimpse-correctness.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
cat > "$tmp/test.cpp" <<'CPP'
#define _DECLARE_TOOLBOX_HERE
#include <io/genotype_bam_caller.h>
#include <models/phasing_hmm.h>
#include <fstream>
#include <stdexcept>
static void check(bool ok, const char *message) {
    if (!ok) throw std::runtime_error(message);
}
static variant *site(int bp, const char *ref, const char *alt, int type, int idx) {
    auto *v = new variant(bp, ".", ref, alt, type, idx, 1, 1, true);
    v->cm = 0; return v;
}
static void pileup(const char *path, char base, int reads) {
    std::ofstream sam(path);
    sam << "@HD\tVN:1.6\tSO:coordinate\n@SQ\tSN:chr1\tLN:100\n";
    for (int r = 0; r < reads; ++r)
        sam << "r" << r << "\t0\tchr1\t1\t60\t1M\t*\t0\t0\t" << base << "\t5\n";
    sam << "filtered\t0\tchr1\t2\t60\t1M\t*\t0\t0\tA\t!\n";
    sam.close();
    variant_map V;
    V.push(site(1, "A", "C", VCF_SNP, 0));
    V.push(site(1, "A", "<DEL>", VCF_OTHER, 1));
    V.push(site(1, "A", "N", VCF_SNP, 2));
    V.push(site(1, "A", "<NON_REF>", VCF_OTHER, 3));
    V.push(site(1, "A", "*", VCF_OTHER, 4));
    V.push(site(1, "A", "G", VCF_SNP, 5));
    V.push(site(2, "A", "C", VCF_SNP, 6));
    V.push(site(2, "A", "G", VCF_SNP, 7));
    V.push(site(3, "A", "C", VCF_SNP, 8));
    haplotype_set H; genotype_set G; glimpse_mpileup M;
    M.tar_ploidy = {2}; M.min_bq = 1; M.max_dp = 1; M.min_mq = 0; M.fflag = 0;
    M.keep_orphan = true; M.check_orientation = M.check_proper_pair = false;
    auto *g = new genotype("sample", 0, 9, 2, 0); g->allocate(); G.vecG.push_back(g);
    G.stats.cov_ind.resize(1); G.stats.depth_count.assign(1, std::vector<int>(2));
    genotype_bam_caller c(H, G, V, M, "chr1:1-3", 1, 3, "standard", false);
    c.caller.ploidy = 2; c.aux_data.fp = sam_open(path, "r");
    check(c.aux_data.fp, "open SAM"); c.aux_data.hdr = sam_hdr_read(c.aux_data.fp);
    check(c.aux_data.hdr, "read SAM header");
    std::vector<int> selected(reads);
    rng.setSeed(17);
    if (reads > 1) std::shuffle(selected.begin(), selected.end(), rng.randomEngine);
    const auto expected_rng = rng.randomEngine;
    rng.setSeed(17);
    check(c.glimpse_mpileup_reg(0) == 0, "pileup status");
    check(rng.randomEngine == expected_rng, "cached split SNPs do not resample reads");
    const std::vector<unsigned char> expected = base == 'A'
        ? std::vector<unsigned char>{0,3,25} : std::vector<unsigned char>{25,3,0};
    check(std::equal(expected.begin(), expected.end(), g->GL.begin()), "normalized nearest PL");
    check(!g->flat[0] && g->flat[5] == (base == 'C'), "split SNP likelihoods");
    const auto split = base == 'A' ? expected : std::vector<unsigned char>{0,0,0};
    check(std::equal(split.begin(), split.end(), g->GL.begin()+15), "split SNP PL");
    for (int l = 1; l < 5; ++l) {
        check(g->flat[l], "non-observable flat flag");
        for (int j = 0; j < 3; ++j) check(g->GL[3*l+j] == 0, "non-observable zero PL");
    }
    for (int l = 6; l < 9; ++l) {
        check(g->flat[l], "filtered and uncovered SNPs are flat");
        for (int j = 0; j < 3; ++j) check(g->GL[3*l+j] == 0, "zero-depth SNP PL");
    }
    check(G.stats.depth_count[0][0] == 7 && G.stats.depth_count[0][1] == 2,
          "split SNP depth across non-observable records");
    check(G.stats.cov_ind[0].size() == 9, "coverage record count");
    std::cout << "PASS normalized PL, zero-depth records and cached split SNPs ("
              << base << ", reads=" << reads << ")\n";
}
static void likelihoods() {
    variant v(1, ".", "A", "C", VCF_SNP, 0, 1, 1, true);
    call_t one{}; one.ploidy = 1; one.bca.max_dp = 100; one.bca.min_bq = 0;
    one.bca.bases = {uint16_t(20 << 5)}; one.gls.read_depth = 1;
    standard_errmod(one, &v);
    call_t repeated{}; repeated.ploidy = 1; repeated.bca.max_dp = 100;
    repeated.bca.bases.assign(7, uint16_t(20 << 5)); repeated.gls.read_depth = 7;
    standard_errmod(repeated, &v);
    for (int j = 0; j < 2; ++j)
        check(std::abs(repeated.gls.llk[j] - 7*one.gls.llk[j]) < 1e-5,
              "haploid identical-read accumulation");
    one.gls.read_depth = 0; standard_errmod(one, &v);
    check(one.gls.dp_ind == 0, "zero reads clear prior depth");
    for (int ploidy : {1,2}) for (unsigned seed = 1; seed <= 16; ++seed) {
        call_t c{}; c.ploidy = ploidy; c.bca.max_dp = 5;
        for (int j = 0; j < 24; ++j) c.bca.bases.push_back(((j+5)<<5) | (j%4));
        c.gls.read_depth = c.bca.bases.size();
        auto expected = c.bca.bases; rng.setSeed(seed);
        std::shuffle(expected.begin(), expected.end(), rng.randomEngine);
        std::sort(expected.begin(), expected.begin()+5);
        rng.setSeed(seed); standard_errmod(c, &v);
        check(c.bca.bases == expected, "sort only retained downsampled prefix");
        call_t retained{}; retained.ploidy = ploidy; retained.bca.max_dp = 100;
        retained.bca.bases.assign(expected.begin(), expected.begin()+5); retained.gls.read_depth = 5;
        standard_errmod(retained, &v);
        check(c.gls.dp_ind == 5 && c.gls.llk == retained.gls.llk, "retained-prefix likelihood");
    }
    std::cout << "PASS haploid read multiplicity and retained-prefix downsampling\n";
}
static void phasing() {
    variant_map V; V.push(site(1, "A", "C", VCF_SNP, 0));
    V.push(site(2, "A", "C", VCF_SNP, 1)); haplotype_set H;
    conditioning_set C(V, H, 2, 2, 2, 2, .001f, .001f, false);
    C.n_states = 2; C.Hvar.allocate(2, 2);
    for (int l = 0; l < 2; ++l) { C.Hvar.set(l,0,0); C.Hvar.set(l,1,1); }
    C.polymorphic_sites = {0};
    bool saw01 = false, saw10 = false;
    for (unsigned seed = 1; seed <= 64; ++seed) {
        std::vector<bool> a{false,false}, b{true,true}, flat{true,true};
        rng.setSeed(seed); (void)rng.getFloat(); const bool rf = rng.getFloat() < .5;
        const auto next = rng.randomEngine();
        rng.setSeed(seed); phasing_hmm hmm(&C); hmm.rephaseHaplotypes(a,b,flat);
        check(a[0] == !rf && b[0] == rf, "sampled 01/10 orientation");
        check(rng.randomEngine() == next, "phasing RNG draw count");
        saw01 |= rf; saw10 |= !rf;
    }
    check(saw01 && saw10, "both sampled orientations");
    C.polymorphic_sites = {0,1};
    for (unsigned seed = 1; seed <= 64; ++seed) {
        std::vector<bool> a{false,false}, b{true,true}, flat{false,true};
        rng.setSeed(seed); phasing_hmm hmm(&C); hmm.rephaseHaplotypes(a,b,flat);
        check(a[1] != b[1], "flat heterozygote complementarity");
        check(a[0] == a[1] && b[0] == b[1], "panel-supported flat orientation");
    }
    std::cout << "PASS complementary flat hets, sampled orientation and RNG draw count\n";
}
int main(int argc, char **argv) {
    try { check(argc == 2, "SAM path argument");
        for (int reads : {1,8}) for (char base : {'A','C'}) pileup(argv[1], base, reads);
        likelihoods(); phasing();
    } catch (const std::exception &e) { std::cerr << "FAIL: " << e.what() << '\n'; return 1; }
}
CPP
"${CXX:-c++}" -std=c++17 -O1 -fno-fast-math -ffp-contract=off -DSIMDE_NO_NATIVE \
    -ffunction-sections -fdata-sections -Wno-psabi -Wno-ignored-attributes \
    -Iphase/src -Icommon/src -Ithird_party/simde \
    "$tmp/test.cpp" phase/src/io/genotype_bam_caller.cpp phase/src/models/phasing_hmm.cpp \
    phase/src/containers/{variant_map,haplotype_set,ref_haplotype_set,genotype_set,glimpse_mpileup,conditioning_set,bitmatrix}.cpp \
    common/src/objects/{variant,genotype}.cpp \
    -Wl,--gc-sections -lhts -lboost_serialization -lboost_iostreams -lz -pthread -o "$tmp/test"
"$tmp/test" "$tmp/reads.sam"
