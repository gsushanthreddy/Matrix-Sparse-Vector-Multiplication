// ESE 507 Stony Brook University
// Peter Milder
// You may not redistribute this code.
// This file contains the DPI functions used in the input_mems_tb and MMM_tb
// testbenches.


#include <svdpi.h>
#include <stdio.h>
#include <time.h>
#include <stdlib.h>

// Given two matrices, compute the matrix-matrix product and store the result in outmat.
void calcOutput(svOpenArrayHandle matrixA, svOpenArrayHandle matrixB, svBitVecVal M, svBitVecVal N, svBitVecVal K, svOpenArrayHandle outmat, svBitVecVal OUTW) {

    // Min and max values, used to check that the results don't overflow the number of bits
    long min = -1*(1l<<(OUTW-1));
    long max = (1l<<(OUTW-1))-1;

    for (int a_row = 0; a_row < M; a_row++) {
        for (int b_col = 0; b_col < N; b_col++) {
            
            long int out = 0;
            
            for (int a_col = 0; a_col < K; a_col++) {
                // get the appropriate matrix values            
                int aVal = *(int*)(svGetArrElemPtr1(matrixA, a_row*K+a_col));
                int bVal = *(int*)(svGetArrElemPtr1(matrixB, a_col*N+b_col));
            
                // Compute the multiply and accumulate.
                // Note: we need to cast these to long ints so that "out" doesn't
                // overflow on this line.
                long prod = (long)aVal * (long)bVal;
                long old_accum = out;
                out += prod;

                // Check for overflow.
                //    - special case if output takes up the full 64 bits available in long 
                if (OUTW == 64) {
                    if ((old_accum > 0) && (prod > 0) && (out < 0)) {
                        out = max;
                    }
                    else if ((old_accum < 0) && (prod < 0) && (out > 0)) {
                        out = min;
                    }
                }
                else {   // if OUTW < 64, we can just check min and max
                    if (out < min)
                        out = min;
                    else if (out > max)
                        out = max;
                }


            }

            // Save the matrix output value
            *(long int*)(svGetArrElemPtr1(outmat,a_row*N+b_col)) = out;

        }
    }
}
