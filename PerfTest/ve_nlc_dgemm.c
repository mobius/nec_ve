/*
 * ve_nlc_dgemm.c - NLC BLAS cblas_dgemm benchmark for NEC VE
 * Uses NEC Numeric Library Collection 3.1.0 cblas_dgemm()
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <cblas.h>

#ifndef N
#define N 4096
#endif

static double now_sec(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec * 1e-9;
}

int main(void) {
    const int n = N;
    double *A = (double *)malloc((size_t)n * n * sizeof(double));
    double *B = (double *)malloc((size_t)n * n * sizeof(double));
    double *C = (double *)malloc((size_t)n * n * sizeof(double));

    if (!A || !B || !C) { fprintf(stderr, "malloc failed\n"); return 1; }

    /* First-touch initialization */
    for (int j = 0; j < n; j++)
        for (int i = 0; i < n; i++) {
            A[i + j*n] = (double)(i + j + 1) / n;
            B[i + j*n] = (double)(i - j + 1) / n;
            C[i + j*n] = 0.0;
        }

    /* Warmup x2 */
    cblas_dgemm(CblasColMajor, CblasNoTrans, CblasNoTrans,
                n, n, n, 1.0, A, n, B, n, 0.0, C, n);
    cblas_dgemm(CblasColMajor, CblasNoTrans, CblasNoTrans,
                n, n, n, 1.0, A, n, B, n, 0.0, C, n);

    /* Timed runs: 5 iterations, take best */
    double best = 0.0;
    const int NRUNS = 5;
    for (int r = 0; r < NRUNS; r++) {
        double t0 = now_sec();
        cblas_dgemm(CblasColMajor, CblasNoTrans, CblasNoTrans,
                    n, n, n, 1.0, A, n, B, n, 0.0, C, n);
        double g = 2.0 * (double)n * n * n / (now_sec() - t0) / 1e9;
        if (g > best) best = g;
    }
    double gflops = best;

    /* Checksum */
    double chk = 0.0;
    for (int i = 0; i < n; i++) chk += C[i*n + i];

    printf("Matrix multiplication: %dx%d x %dx%d  (NLC cblas_dgemm)\n", n, n, n, n);
    printf("GFlops: %.2f\n", gflops);
    printf("Checksum: %.6f\n", chk);
    printf("Result: %s\n", (gflops > 400.0) ? "PASS" : "FAIL");

    free(A); free(B); free(C);
    return 0;
}
