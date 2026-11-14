/* PC test harness: reads float32 rows (N x 7) from a file, prints one CSV line per decision.
 *   native_harness rows.bin > decisions.csv */
#include <stdio.h>
#include <stdlib.h>

#include "glove_core.h"

int main(int argc, char **argv) {
    if (argc < 2) return 2;
    FILE *f = fopen(argv[1], "rb");
    if (!f) return 3;
    fseek(f, 0, SEEK_END);
    const long bytes = ftell(f);
    fseek(f, 0, SEEK_SET);
    const int n = (int)(bytes / (long)(sizeof(float) * GLOVE_CHANNELS));
    float *rows = malloc((size_t)bytes);
    if (!rows || fread(rows, sizeof(float), (size_t)n * GLOVE_CHANNELS, f) != (size_t)n * GLOVE_CHANNELS) return 4;
    fclose(f);

    glove_t g;
    glove_init(&g);
    glove_output_t out;
    for (int i = 0; i < n; i++) {
        if (glove_push(&g, rows + (size_t)i * GLOVE_CHANNELS, &out)) {
            printf("%d,%d,%.6f,%d,%d\n", i, out.gesture, out.confidence, (int)out.command, out.speed);
        }
    }
    free(rows);
    return 0;
}