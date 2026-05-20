#include <mpi.h>
#include <stdio.h>

int main(int argc, char *argv[]) {
    int rank, size;
    double local = 1.0;
    double global = 0.0;

    MPI_Init(&argc, &argv);
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &size);

    MPI_Allreduce(&local, &global, 1, MPI_DOUBLE, MPI_SUM, MPI_COMM_WORLD);

    if (rank == 0) {
        printf("AllReduce result: %.1f (expected: %d)\n", global, size);
        if (global == (double)size) {
            printf("MPI AllReduce: PASS\n");
        } else {
            printf("MPI AllReduce: FAIL\n");
        }
    }

    MPI_Finalize();
    return 0;
}
