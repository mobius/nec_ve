#include <stdio.h>
#include <unistd.h>

int main() {
    long pages = sysconf(_SC_PHYS_PAGES);
    long page_size = sysconf(_SC_PAGE_SIZE);

    if (pages < 0 || page_size < 0) {
        printf("Failed to query memory info\n");
        return 1;
    }

    unsigned long long total_mem = (unsigned long long)pages * (unsigned long long)page_size;
    double total_gb = total_mem / (1024.0 * 1024.0 * 1024.0);

    printf("Page size: %ld bytes\n", page_size);
    printf("Total pages: %ld\n", pages);
    printf("Total Memory: %.1f GB\n", total_gb);

    if (total_gb >= 45.0) {
        printf("Result: PASS (>= 45 GB)\n");
        return 0;
    } else {
        printf("Result: FAIL (< 45 GB)\n");
        return 1;
    }
}
