#include <stdio.h>
#include <stdlib.h>
#include <sys/time.h>

#define N 4096

double get_time() {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return tv.tv_sec + tv.tv_usec * 1e-6;
}

int main() {
    double *A = (double*)aligned_alloc(64, N * N * sizeof(double));
    double *B = (double*)aligned_alloc(64, N * N * sizeof(double));
    double *C = (double*)aligned_alloc(64, N * N * sizeof(double));

    for (int i = 0; i < N * N; i++) {
        A[i] = (double)(i % 100) / 100.0;
        B[i] = (double)(i % 100) / 100.0;
        C[i] = 0.0;
    }

    double start = get_time();

    for (int i = 0; i < N; i++) {
        for (int k = 0; k < N; k++) {
            double a = A[i * N + k];
            #pragma omp simd
            for (int j = 0; j < N; j++) {
                C[i * N + j] += a * B[k * N + j];
            }
        }
    }

    double end = get_time();
    double elapsed = end - start;
    double ops = 2.0 * N * N * N;
    double gflops = ops / elapsed / 1e9;

    double checksum = 0.0;
    for (int i = 0; i < N * N; i++) {
        checksum += C[i];
    }

    printf("Matrix multiplication: %dx%d x %dx%d\n", N, N, N, N);
    printf("Time: %.4f seconds\n", elapsed);
    printf("Checksum: %.4f\n", checksum);
    printf("GFlops: %.2f\n", gflops);

    if (elapsed > 0 && gflops > 0) {
        printf("Result: PASS\n");
    } else {
        printf("Result: FAIL\n");
    }

    free(A);
    free(B);
    free(C);
    return 0;
}
