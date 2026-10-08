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

#ifndef _HAPLOTYPE_HMM_H
#define _HAPLOTYPE_HMM_H

#include <utils/otools.h>
#include <containers/conditioning_set.h>
#include <simde/x86/avx2.h>
#include <simde/x86/fma.h>
#include <boost/align/aligned_allocator.hpp>

template <typename T>
using aligned_vector32 = std::vector<T, boost::alignment::aligned_allocator < T, 32 > >;

class imputation_hmm {
private:
	conditioning_set * C;
	unsigned int modK;

	//The forward table is checkpointed: one Alpha row every CKPT_BLOCK polymorphic
	//sites is kept, and the backward pass recomputes each block of rows into a
	//small buffer with exactly the arithmetic of the forward pass. Posteriors are
	//bit-identical to a full table; memory drops from n_poly x modK floats to
	//(n_poly / CKPT_BLOCK + CKPT_BLOCK) x modK floats and the block stays in cache.
	static constexpr unsigned int CKPT_BLOCK = 64;

	//DYNAMIC ARRAYS
	aligned_vector32 < float > Emissions;
	aligned_vector32 < float > AlphaCkpt;		//checkpoint rows, one per CKPT_BLOCK sites
	aligned_vector32 < float > AlphaBlock;		//scratch rows for the current block
	aligned_vector32 < float > AlphaSum;
	aligned_vector32 < float > Beta;

	inline bool isFlat(const std::vector < bool > & flat, const unsigned int l) const {
		return flat[C->polymorphic_sites[l]] || C->lq_flag[C->polymorphic_sites[l]];
	}
	inline float * rowSlot(const unsigned int l) {
		return (l % CKPT_BLOCK == 0) ? &AlphaCkpt[(size_t)(l / CKPT_BLOCK) * modK] : &AlphaBlock[(size_t)(l % CKPT_BLOCK) * modK];
	}
	float forwardRow(const unsigned int l, const float * prev, const float prevSum, float * out, const bool flat_l);

public:
	//CONSTRUCTOR/DESTRUCTOR
	imputation_hmm(conditioning_set *);
	~imputation_hmm();

	void resize();
	void init(const std::vector < float > &);
	void forward(std::vector < bool > &);
	void backward(const std::vector < float > &, std::vector < bool > &, std::vector < float > &);
	void computePosteriors(const std::vector < float > &, std::vector < bool > &, std::vector < float > &);

};

#endif
