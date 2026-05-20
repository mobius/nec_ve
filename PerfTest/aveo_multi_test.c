#include <stdio.h>
#include <stdlib.h>
#include <ve_offload.h>

int main(int argc, char *argv[]) {
    int nodes[3];
    int count;

    if (argc > 1) {
        count = argc - 1;
        if (count > 3) count = 3;
        for (int i = 0; i < count; i++) {
            nodes[i] = atoi(argv[i + 1]);
        }
    } else {
        // Default: try 1, 2, 3 (common for three-card systems)
        nodes[0] = 1; nodes[1] = 2; nodes[2] = 3;
        count = 3;
    }

    struct veo_proc_handle *proc[3];
    int success = 0;

    for (int i = 0; i < count; i++) {
        proc[i] = veo_proc_create(nodes[i]);
        if (proc[i] == NULL) {
            printf("VE%d: proc_create FAILED\n", nodes[i]);
            continue;
        }
        printf("VE%d: proc_create OK\n", nodes[i]);
        success++;
    }

    for (int i = 0; i < count; i++) {
        if (proc[i] == NULL) continue;
        int ret = veo_proc_destroy(proc[i]);
        printf("VE%d: proc_destroy %s\n", nodes[i], ret == 0 ? "OK" : "FAILED");
    }

    if (success == count) {
        printf("AVEO Multi-Device: PASS\n");
        return 0;
    } else {
        printf("AVEO Multi-Device: FAIL (%d/%d succeeded)\n", success, count);
        return 1;
    }
}
