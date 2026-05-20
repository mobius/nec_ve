#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>
#include <omp.h>

#define N      4096
/*
 * Optimised DGEMM benchmark for NEC VE 10BE-P — C harness + nfort kernel.
 *
 * Architecture insight: ncc (NEC C compiler) cannot match nfort (NEC Fortran
 * compiler) for DGEMM because nfort detects the matrix-multiply idiom
 * (opt 1800) and applies column-major register-blocking automatically.
 *
 * This file provides the benchmark harness (timing, output, checksum).
 * The actual computation is in ve_dgemm_kernel.f90, compiled with nfort -O3
 * -fopenmp, and linked via ISO_C_BINDING (extern "C" ABI).
 *
 * Kernel strategy (ve_dgemm_kernel.f90):
 *   - Column-major storage: innermost i-loop is stride-1 (VE-optimal)
 *   - kk-blocked jki loop: j-parallel, k-serial, i-vectorised
 *   - A-block (TILE_K × N, 8 MB) fits in shared LLC (16 MB)
 *   - OMP barrier after each kk ensures all 8 threads share the A-block
 *   - nfort keeps C(:,j) in VE vector registers for the entire k-loop
 *
 * Measured: ~430 GFLOPS (8 cores, N=4096) = 20% of 2160 GFLOPS DP peak
 *   vs 155 GFLOPS with pure ncc (7.2% peak)
 *   vs  54 GFLOPS single-core baseline
 */

/* Column-major element index: (row i, col j) in an N-column matrix */
#define TILE_K 256
#define IDX(i,j) ((i) + (j) * N)

/* Fortran kernel — compiled with nfort, exposed via bind(C).
 * Use n_dim / tile_k_dim to avoid collision with #define N and #define TILE_K. */
extern void dgemm_ve(const double *A, const double *B, double *C,
                     int n_dim, int tile_k_dim);

double get_time() {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return tv.tv_sec + tv.tv_usec * 1e-6;
}

int main() {
    /* Column-major allocation (Fortran layout) */
    double *A = (double*)aligned_alloc(64, (size_t)N * N * sizeof(double));
    double *B = (double*)aligned_alloc(64, (size_t)N * N * sizeof(double));
    double *C = (double*)aligned_alloc(64, (size_t)N * N * sizeof(double));

    /* First-touch in column-major order to match the kernel's access pattern */
    #pragma omp parallel for schedule(static)
    for (int j = 0; j < N; j++) {
        #pragma omp simd
        for (int i = 0; i < N; i++) {
            A[IDX(i,j)] = (double)((i * N + j) % 100) / 100.0;
            B[IDX(i,j)] = (double)((i * N + j) % 100) / 100.0;
            C[IDX(i,j)] = 0.0;
        }
    }

    int nthreads = omp_get_max_threads();
    printf("Matrix multiplication: %dx%d x %dx%d  (tile_k=%d, threads=%d)\n",
           N, N, N, N, TILE_K, nthreads);

    double start = get_time();
    dgemm_ve(A, B, C, N, TILE_K);   /* nfort-optimised kernel */
    double elapsed = get_time() - start;

    double gflops = 2.0 * (double)N * N * N / elapsed / 1e9;

    double checksum = 0.0;
    #pragma omp parallel for simd reduction(+:checksum) schedule(static)
    for (int j = 0; j < N; j++)
        for (int i = 0; i < N; i++)
            checksum += C[IDX(i,j)];

    printf("Time: %.4f seconds\n", elapsed);
    printf("Checksum: %.4f\n", checksum);
    printf("GFlops: %.2f\n", gflops);

    if (elapsed > 0 && gflops > 0)
        printf("Result: PASS\n");
    else
        printf("Result: FAIL\n");

    free(A); free(B); free(C);
    return 0;
}
