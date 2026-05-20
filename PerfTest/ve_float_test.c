#include <stdio.h>
#include <stdlib.h>
#include <math.h>

#define N 10000000

double dot_product(const double *a, const double *b, int n) {
    double sum = 0.0;
    #pragma omp simd
    for (int i = 0; i < n; i++) {
        sum += a[i] * b[i];
    }
    return sum;
}

int main() {
    double *a = (double*)malloc(N * sizeof(double));
    double *b = (double*)malloc(N * sizeof(double));

    for (int i = 0; i < N; i++) {
        a[i] = (double)(i + 1);
        b[i] = 1.0;
    }

    double result = dot_product(a, b, N);
    double expected = (double)N * (N + 1) / 2.0;

    printf("Array size: %d\n", N);
    printf("Dot product result: %.10f\n", result);
    printf("Expected:         %.10f\n", expected);
    printf("Difference:       %.10e\n", fabs(result - expected));

    if (fabs(result - expected) < 1e-6) {
        printf("Result: PASS\n");
        free(a);
        free(b);
        return 0;
    } else {
        printf("Result: FAIL\n");
        free(a);
        free(b);
        return 1;
    }
}
