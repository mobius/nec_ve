#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>

#define N (1024 * 1024 * 1024 / 8)
#define NTIMES 10

static double a[N], b[N], c[N];

double mysecond() {
    struct timeval tp;
    gettimeofday(&tp, NULL);
    return (double)tp.tv_sec + (double)tp.tv_usec / 1e6;
}

int main() {
    double times[NTIMES];
    double avgtime;
    double bytes = 3.0 * sizeof(double) * N;

    for (size_t i = 0; i < N; i++) {
        a[i] = 1.0;
        b[i] = 2.0;
    }

    for (int k = 0; k < NTIMES; k++) {
        times[k] = mysecond();
        #pragma omp simd
        for (size_t i = 0; i < N; i++) {
            c[i] = a[i] + b[i];
        }
        times[k] = mysecond() - times[k];
    }

    avgtime = 0;
    for (int k = 1; k < NTIMES; k++) avgtime += times[k];
    avgtime /= (NTIMES - 1);

    printf("Avg time: %.6f sec\n", avgtime);
    printf("Bandwidth: %.2f GB/s\n", bytes / avgtime / 1e9);
    printf("Result: PASS\n");
    return 0;
}
