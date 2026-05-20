#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>
#include <ve_offload.h>

#define SIZE (1024 * 1024 * 100)
#define ITER 10

double get_time() {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return tv.tv_sec + tv.tv_usec * 1e-6;
}

int main(int argc, char *argv[]) {
    int node = (argc > 1) ? atoi(argv[1]) : 0;
    struct veo_proc_handle *proc = veo_proc_create(node);
    if (!proc) {
        printf("VE%d: proc_create failed\n", node);
        return 1;
    }

    uint64_t ve_ptr;
    if (veo_alloc_mem(proc, &ve_ptr, SIZE) != 0) {
        printf("VE%d: alloc_mem failed\n", node);
        veo_proc_destroy(proc);
        return 1;
    }

    char *host_buf = (char*)malloc(SIZE);
    if (!host_buf) {
        printf("VE%d: host malloc failed\n", node);
        veo_free_mem(proc, ve_ptr);
        veo_proc_destroy(proc);
        return 1;
    }
    memset(host_buf, 0xAB, SIZE);

    double start = get_time();
    for (int i = 0; i < ITER; i++) {
        if (veo_write_mem(proc, ve_ptr, host_buf, SIZE) != 0) {
            printf("VE%d: write_mem failed on iter %d\n", node, i);
        }
    }
    double h2d_time = (get_time() - start) / ITER;

    start = get_time();
    for (int i = 0; i < ITER; i++) {
        if (veo_read_mem(proc, host_buf, ve_ptr, SIZE) != 0) {
            printf("VE%d: read_mem failed on iter %d\n", node, i);
        }
    }
    double d2h_time = (get_time() - start) / ITER;

    double bw_h2d = (SIZE / h2d_time) / 1e9;
    double bw_d2h = (SIZE / d2h_time) / 1e9;

    printf("VE%d H2D: %.2f GB/s\n", node, bw_h2d);
    printf("VE%d D2H: %.2f GB/s\n", node, bw_d2h);

    veo_free_mem(proc, ve_ptr);
    veo_proc_destroy(proc);
    free(host_buf);
    return 0;
}
