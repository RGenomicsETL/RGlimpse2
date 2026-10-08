/*******************************************************************************
 * Copyright (C) 2022-2023 Simone Rubinacci
 * Copyright (C) 2022-2023 Olivier Delaneau
 *
 * MIT Licence
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 ******************************************************************************/

#include <containers/conditioning_set.h>
#include <algorithm>

conditioning_set::conditioning_set(const variant_map & _mapG, const haplotype_set & _H, const unsigned int _n_ref_haps, const unsigned int _n_eff_haps, const int _kinit, const int _kpbwt, const float _err_imp, const float _err_phs, const bool use_list):
		mapG(_mapG), H(_H), n_ref_haps(_n_ref_haps),
		n_eff_haps(_n_eff_haps),
		n_com_sites(H.common2tot.size()),
		n_tot_sites(mapG.size()),
		nrho(use_list ? (-0.04 * n_eff_haps) / std::max(n_ref_haps,n_eff_haps) : (-0.04 * n_eff_haps) / n_ref_haps),
		one_l(1.0 - 1e-7),
		ed_phs(_err_phs),
		ee_phs(1.0 -_err_phs),
		ed_imp(_err_imp),
		ee_imp(1.0 - _err_imp),
		Kinit(_kinit), Kpbwt(_kpbwt),
		cached_full_panel_n(0),
		transitions_valid(false)
{
	var_type = std::vector < unsigned char > (n_tot_sites);
	major_alleles = H.major_alleles;

	idxHaps_ref.clear();

	n_states = 0;
	Svar = std::vector < std::vector < unsigned int > > (n_tot_sites);

	//Build flags of HQ or LQ sites
	lq_flag = std::vector < bool > (n_tot_sites, true);
	for (int l = 0 ; l < mapG.vec_pos.size() ; l ++) lq_flag[l] = mapG.vec_pos[l]->LQ;
}

conditioning_set::~conditioning_set() {
	n_eff_haps=0;
	n_tot_sites=0;
	var_type.clear();
	idxHaps_ref.clear();
	polymorphic_sites.clear();
	monomorphic_sites.clear();
	major_alleles.clear();
	n_states=0;
	t.clear();
	nt.clear();
}

void conditioning_set::select(const int ind, const int iter) {
	compactSelection(ind, iter);
	updateTransitions();
}

void conditioning_set::compactSelection(const int ind, const int iter)
{
	bool use_list = true;
	const int hapid=H.tar_ind2hapid[ind];
	const int ploidyM1 = H.tar_ploidy[ind]-1;
	idxHaps_ref.clear();

	if (iter==STAGE_INIT && Kinit > 0)
	{
		std::copy(H.init_states[ind].begin(), H.init_states[ind].end(), std::back_inserter(idxHaps_ref));
	}
	else if (iter==STAGE_RESTRICT && Kpbwt > 0)
	{
		const int k_pbwt = std::max(Kpbwt/10,350);
		std::set<int> states_ind;
		for (int i=0; i<H.pbwt_states[ind].size() && (states_ind.size() < k_pbwt || i<=1); ++i)
			for (int j=H.pbwt_states[ind][i].size()-1; j>=0; --j)
				states_ind.insert(H.pbwt_states[ind][i][j]);

		std::copy(states_ind.begin(), states_ind.end(), std::back_inserter(idxHaps_ref));
	}
	else if (Kpbwt > 0 && Kpbwt < H.n_ref_haps)
	{
		std::set<int> states_ind;
		for (int i=0; i<H.pbwt_states[ind].size() && states_ind.size() < Kpbwt; ++i)
			for (int j=H.pbwt_states[ind][i].size()-1; j>=0 && states_ind.size() < Kpbwt; --j)
				states_ind.insert(H.pbwt_states[ind][i][j]);

		std::copy(states_ind.begin(), states_ind.end(), std::back_inserter(idxHaps_ref));
	}
	else if (Kpbwt >= H.n_ref_haps)
	{
		use_list = false;
		//Cache hit: the full-panel selection produces the same derived state every
		//time, so reuse the result of the previous build (see header for details).
		if (cached_full_panel_n == H.n_ref_haps) return;
		idxHaps_ref.resize(H.n_ref_haps);
		std::iota(idxHaps_ref.begin(), idxHaps_ref.end(), 0);
	}
	//Kpbwt == 0 easy: just go here..
	if (use_list && (H.list_states[hapid].size() > 0 || H.list_states[hapid+ploidyM1].size() > 0))
	{
		std::copy(H.list_states[hapid].begin(), H.list_states[hapid].end(), std::back_inserter(idxHaps_ref));
		if (ploidyM1) std::copy(H.list_states[hapid+1].begin(), H.list_states[hapid+1].end(), std::back_inserter(idxHaps_ref));
		sort(idxHaps_ref.begin(), idxHaps_ref.end());
		idxHaps_ref.erase(unique(idxHaps_ref.begin(), idxHaps_ref.end()), idxHaps_ref.end());
	}

	//Check #states
	n_states = idxHaps_ref.size();
	if (n_states == 0) vrb.error("States for individual " + std::to_string(ind) + " are zero. Error during selection.");

	//Update Svar by looking at sparse matrixes of conditioning haplotypes [this is quite costly, very inefficient at the cache level]
	for (int l = 0 ; l < n_tot_sites ; l++) Svar[l].clear();
	for (int k = 0 ; k < idxHaps_ref.size() ; k++) {
		for (int r = 0 ; r < H.ShapRef[idxHaps_ref[k]].size() ; r++) {
			Svar[H.ShapRef[idxHaps_ref[k]][r]].push_back(k);
		}
	}
	//Update var_type
	monomorphic_sites.clear();
	polymorphic_sites.clear();
	for (int l = 0 ; l < n_tot_sites ; l++) {
		if (H.flag_common[l]) var_type[l] = TYPE_COMMON;
		else if (Svar[l].size()) var_type[l] = TYPE_RARE;
		else var_type[l] = TYPE_MONO;
		if (var_type[l] == TYPE_MONO) monomorphic_sites.push_back(l);
		else polymorphic_sites.push_back(l);
	}

	//Build bitmatrix Hvar: rare rows directly from the sparse carriers, common
	//rows by transposing the selected rows of the haplotype-major panel copy.
	Hvar.reallocate(polymorphic_sites.size(), n_states);
	rel_of_com.clear();
	for (int labs = 0, lrel = 0 ; labs < n_tot_sites ; labs ++) {
		if (var_type[labs] == TYPE_COMMON) {
			rel_of_com.push_back(lrel);
			lrel++;
		} else if (var_type[labs] == TYPE_RARE) {
			Hvar.set(lrel, major_alleles[labs]);
			for (int r = 0 ; r < Svar[labs].size() ; r++) Hvar.set(lrel, Svar[labs][r], !major_alleles[labs]);
			lrel++;
		} //else mono: do nothing
	}
	buildCommonRows();

	//We just rebuilt polymorphic_sites, so any previously computed t/nt are stale.
	//Mark the full-panel cache as valid only if we actually took that path.
	transitions_valid = false;
	cached_full_panel_n = use_list ? 0 : H.n_ref_haps;
}


//Fill the common-site rows of Hvar for the selected states. Each group of 8
//states contributes one byte per Hvar row: the 8 haplotype rows are read
//sequentially from H.HhapRef and transposed 8x8 bits at a time. Sites are
//processed in tiles so the Hvar rows being written stay in cache. Bit order
//matches bitmatrix::set(): state k+b -> bit (7-b).
void conditioning_set::buildCommonRows()
{
	const unsigned int n_com = rel_of_com.size();
	if (n_com == 0) return;
	const size_t hapRowB = H.HhapRef.n_cols / 8;
	if (zero_hap_row.size() < hapRowB) zero_hap_row.assign(hapRowB, 0);
	const unsigned int n_com_bytes = (n_com + 7) / 8;
	const unsigned int TILE_BYTES = 256;
	unsigned char in[8], out[8];
	for (unsigned int j0 = 0 ; j0 < n_com_bytes ; j0 += TILE_BYTES)
	{
		const unsigned int j1 = std::min(n_com_bytes, j0 + TILE_BYTES);
		for (unsigned int k = 0 ; k < n_states ; k += 8)
		{
			const unsigned char * hp[8];
			for (int b = 0 ; b < 8 ; b ++) hp[b] = (k + b < n_states) ? H.HhapRef.bytes + (size_t)idxHaps_ref[k + b] * hapRowB : zero_hap_row.data();
			for (unsigned int j = j0 ; j < j1 ; j ++)
			{
				for (int b = 0 ; b < 8 ; b ++) in[b] = hp[b][j];
				bitmatrix_transpose8x8(in, out);
				const unsigned int smax = std::min(8u, n_com - 8 * j);
				for (unsigned int s = 0 ; s < smax ; s ++) Hvar.setByte(rel_of_com[8 * j + s], k, out[s]);
			}
		}
	}
}

void conditioning_set::updateTransitions()
{
	if (polymorphic_sites.size() == 0) return;
	if (transitions_valid) return;
	t.resize(polymorphic_sites.size() - 1);
	nt.resize(polymorphic_sites.size() - 1);
	for (int l = 1 ; l < polymorphic_sites.size() ; l ++)
	{
		t[l-1] = std::clamp(-expm1(nrho * (mapG.vec_pos[polymorphic_sites[l]]->cm - mapG.vec_pos[polymorphic_sites[l-1]]->cm)), 1e-7, one_l);
		nt[l-1] = 1.0f-t[l-1];
	}
	transitions_valid = true;
}
