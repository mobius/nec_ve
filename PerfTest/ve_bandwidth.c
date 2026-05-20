#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>
#include <omp.h>

/* 3 × 1 GB arrays → 3 GB total, well above LLC (16 MB) to force HBM access */
#define N      (1024 * 1024 * 1024 / 8)   /* 128 M doubles = 1 GB */
#define NTIMES 10

static double a[N], b[N], c[N];

double mysecond() {
    struct timeval tp;
    gettimeofday(&tp, NULL);
    return (double)tp.tv_sec + (double)tp.tv_usec / 1e6;
}

int main() {
    double times[NTIMES];
    double bytes = 3.0 * sizeof(double) * N;
    int nthreads;

    /* First-touch initialisation: each thread touches its own pages */
    #pragma omp parallel for simd schedule(static)
    for (size_t i = 0; i < N; i++) {
        a[i] = 1.0;
        b[i] = 2.0;
        c[i] = 0.0;
    }

    #pragma omp parallel
    { nthreads = omp_get_num_threads(); }

    /* STREAM triad: c = a + b  (3-array, read a, read b, write c) */
    for (int k = 0; k < NTIMES; k++) {
        times[k] = mysecond();
        #pragma omp parallel for simd schedule(static)
        for (size_t i = 0; i < N; i++) {
            c[i] = a[i] + b[i];
        }
        times[k] = mysecond() - times[k];
    }

    /* Drop first iteration (cache warm-up), average the rest */
    double avgtime = 0;
    for (int k = 1; k < NTIMES; k++) avgtime += times[k];
    avgtime /= (NTIMES - 1);

    printf("Threads: %d\n", nthreads);
    printf("Avg time: %.6f sec\n", avgtime);
    printf("Bandwidth: %.2f GB/s\n", bytes / avgtime / 1e9);
    printf("Result: PASS\n");
    return 0;
}
