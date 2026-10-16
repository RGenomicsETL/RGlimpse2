// Independent retention/encoding and ligation oracle; no new scientific sampler.
#define _DECLARE_TOOLBOX_HERE
#include <objects/genotype.h>
#include <ligater/ligater_header.h>
#include <stdexcept>

static void check(bool condition, const char * message) {
    if (!condition) throw std::runtime_error(message);
}

static void retention(int ploidy) {
    genotype sampled("sample", 0, 4, ploidy, 0);
    genotype ordinary("sample", 0, 4, ploidy, 0);
    sampled.allocate(); ordinary.allocate();
    sampled.sampled_haplotypes.assign(4, 0U);
    // GP elides the first site despite its deliberately retained sampled ALT.
    const std::vector<float> hp{1,0, .5f,.5f, 0,1, .75f,.25f};
    uint32_t expected[4] = {0,0,0,0};
    rng.setSeed(137);
    const auto rng_before = rng.getEngine();
    for (int draw = 0; draw < 15; ++draw) {
        for (int site = 0; site < 4; ++site) {
            const bool first = (draw + site) % 3 == 0;
            const bool second = (draw + site) % 3 == 1;
            sampled.H0[site] = ordinary.H0[site] = first;
            if (ploidy == 2) sampled.H1[site] = ordinary.H1[site] = second;
            // Arithmetic oracle, independent of the retention bit operations.
            expected[site] += (unsigned(first) + (ploidy == 2 ? 2U * unsigned(second) : 0U))
                * uint32_t(std::pow(4.0, draw));
        }
        sampled.storeHaplotypeSample();
        if (ploidy == 2) {
            sampled.storeGenotypePosteriorsAndHaplotypes(hp, hp);
            ordinary.storeGenotypePosteriorsAndHaplotypes(hp, hp);
        } else {
            sampled.storeGenotypePosteriorsAndHaplotypes(hp);
            ordinary.storeGenotypePosteriorsAndHaplotypes(hp);
        }
    }
    check(rng_before == rng.getEngine(), "retention consumes no RNG");
    check(ordinary.sampled_haplotypes.empty(), "disabled export has no dense storage");
    check(sampled.stored_cnt == 15 && sampled.stored_data[0].idx == 1, "sparse GP omits site zero");
    check(sampled.sampled_haplotypes[0] > 0, "sampled alleles survive sparse GP omission");
    for (int site = 0; site < 4; ++site) {
        check(sampled.sampled_haplotypes[site] == expected[site], "all 15 main draws retained in order");
        check(expected[site] < (1U << 30), "signed BCF bound");
        if (ploidy == 1) check((expected[site] & 0x2aaaaaaaU) == 0, "haploid padding is zero");
    }
    sampled.sortAndNormAndInferGenotype(); ordinary.sortAndNormAndInferGenotype();
    check(sampled.H0 == ordinary.H0 && sampled.H1 == ordinary.H1, "GT unchanged");
    for (int index = 0; index < ordinary.stored_data.size(); ++index) {
        const auto & a = sampled.stored_data[index]; const auto & b = ordinary.stored_data[index];
        check(a.idx == b.idx && a.gp0 == b.gp0 && a.gp1 == b.gp1 && a.hds == b.hds, "GP and phase unchanged");
    }
}

static void orientation() {
    bcf_hdr_t * hdr = bcf_hdr_init("w");
    bcf_hdr_append(hdr, "##contig=<ID=1>");
    bcf_hdr_append(hdr, "##FORMAT=<ID=GT,Number=1,Type=String,Description=\"GT\">");
    bcf_hdr_append(hdr, "##FORMAT=<ID=HS,Number=1,Type=Integer,Description=\"HS\">");
    bcf_hdr_append(hdr, "##INFO=<ID=HSC,Number=1,Type=String,Description=\"scope\">");
    for (const char * name : {"diploid", "haploid", "keep", "missing"}) bcf_hdr_add_sample(hdr, name);
    bcf_hdr_add_sample(hdr, NULL);
    check(bcf_hdr_sync(hdr) == 0, "header sync");
    bcf1_t * line = bcf_init();
    bcf_update_alleles_str(hdr, line, "A,C");
    int32_t gt[] = {bcf_gt_phased(0), bcf_gt_phased(1), bcf_gt_phased(1), bcf_int32_vector_end,
                    bcf_gt_phased(1), bcf_gt_phased(0), bcf_gt_phased(0), bcf_gt_phased(1)};
    int32_t hs[] = {0x15555555, 0x15555555, 9, bcf_int32_missing};
    bcf_update_genotypes(hdr, line, gt, 8);
    bcf_update_format_int32(hdr, line, "HS", hs, 4);
    bcf_update_info_string(hdr, line, "HSC", "1:1-100:20-80");
    ligater ligation;
    ligation.GTa = NULL; ligation.mGTa = 0;
    ligation.swap_phase[0] = {true, true, false, true};
    ligation.phase_update(hdr, line, false);
    int32_t * observed = NULL; int capacity = 0;
    check(bcf_get_format_int32(hdr, line, "HS", &observed, &capacity) == 4, "HS cardinality");
    check(observed[0] == 0x2aaaaaaa, "every diploid draw swapped including draw 15");
    check(observed[1] == hs[1], "haploid sample never swapped in mixed cohort");
    check(observed[2] == 9 && observed[3] == bcf_int32_missing, "unchanged and missing samples preserved");
    check(bcf_gt_allele(ligation.GTa[0]) == 1 && bcf_gt_allele(ligation.GTa[1]) == 0, "GT orientation follows swap");
    char * scope = NULL; int scope_capacity = 0;
    check(bcf_get_info_string(hdr, line, "HSC", &scope, &scope_capacity) > 0, "scope retained");
    check(std::string(scope) == "1:1-100:20-80", "scope unchanged by orientation");
    free(scope); free(observed); free(ligation.GTa);
    bcf_destroy(line); bcf_hdr_destroy(hdr);
}

int main() {
    try {
        retention(1); retention(2); orientation();
        std::cout << "PASS dense retention, 15-draw encoding, haploid padding, RNG/GP/GT parity and mixed-ploidy ligation\n";
    } catch (const std::exception & error) {
        std::cerr << "FAIL: " << error.what() << '\n'; return 1;
    }
}
