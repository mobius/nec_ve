#include <mpi.h>
#include <stdio.h>

int main(int argc, char *argv[]) {
    int rank, size;
    char msg[1];
    MPI_Status status;
    double t1, t2;

    MPI_Init(&argc, &argv);
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &size);

    if (size != 2) {
        if (rank == 0) printf("Run with exactly 2 ranks\n");
        MPI_Finalize();
        return 1;
    }

    if (rank == 0) {
        t1 = MPI_Wtime();
        for (int i = 0; i < 1000; i++) {
            MPI_Send(msg, 1, MPI_CHAR, 1, 0, MPI_COMM_WORLD);
            MPI_Recv(msg, 1, MPI_CHAR, 1, 0, MPI_COMM_WORLD, &status);
        }
        t2 = MPI_Wtime();
        double latency = (t2 - t1) / 1000.0 * 1e6 / 2.0;
        printf("Ping-pong latency: %.2f us\n", latency);
    } else {
        for (int i = 0; i < 1000; i++) {
            MPI_Recv(msg, 1, MPI_CHAR, 0, 0, MPI_COMM_WORLD, &status);
            MPI_Send(msg, 1, MPI_CHAR, 0, 0, MPI_COMM_WORLD);
        }
    }

    MPI_Finalize();
    return 0;
}
