/* Portable C core of the glove: spike filter, window, features, Random Forest, command and speed.
 * Mirrors ml/pipeline.py (default settings). No Arduino or ESP-IDF dependency, so it also
 * compiles on a PC (see ml/verify_c.py). */
#ifndef GLOVE_CORE_H
#define GLOVE_CORE_H

#include "gesture_labels.h"

#ifdef __cplusplus
extern "C" {
#endif

#define GLOVE_CHANNELS 7   /* flex, ax, ay, az, gx, gy, gz (flex in ADC units, acc in g, gyro in deg/s) */
#define GLOVE_WINDOW   25  /* must match ml/config.py WINDOW */
#define GLOVE_STEP     5   /* must match ml/config.py STEP */
#define GLOVE_MEDIAN   5   /* must match ml/config.py MEDIAN_N */
#define GLOVE_FEATURES 40  /* 5 statistics x (7 channels + acceleration norm) */

typedef enum {
    CMD_STOP = 0,
    CMD_FORWARD = 1,
    CMD_TURN_LEFT = 2,
    CMD_TURN_RIGHT = 3
} glove_command_t;

typedef struct {
    int gesture;                    /* index into GESTURE_NAMES */
    float confidence;               /* probability of that gesture, 0..1 */
    glove_command_t command;
    int speed;                      /* 0..255 */
    float proba[GESTURE_COUNT];     /* probability of every class (telemetry, test panel) */
} glove_output_t;

typedef struct {
    /* settings (can be changed at runtime, for example from a CoAP PUT /config) */
    float threshold;                /* below this confidence the gesture is UNKNOWN */
    int open_adc, closed_adc;       /* flex calibration: ADC value with an open hand and a closed fist */
    float lo, hi;                   /* openness below lo gives speed 0, above hi gives full speed */
    int vmax;
    float ema_alpha;
    int deadband;                   /* flex changes smaller than this (ADC units) are ignored */
    int max_rise;                   /* max speed increase per decision */
    glove_command_t mapping[GESTURE_COUNT];

    /* internal state */
    float raw[GLOVE_MEDIAN][GLOVE_CHANNELS];
    int raw_head, raw_count;
    float win[GLOVE_WINDOW][GLOVE_CHANNELS];
    int win_head, win_count, since;
    float flex;
    int flex_init;
    int speed;
} glove_t;

void glove_init(glove_t *g);
void glove_set_threshold(glove_t *g, float threshold);
void glove_set_calibration(glove_t *g, int open_adc, int closed_adc);
void glove_set_mapping(glove_t *g, int gesture, glove_command_t command);

/* Feed one sample (call at 50 Hz). Returns 1 and fills `out` when a new decision is ready
 * (every GLOVE_STEP samples once the window is full), otherwise 0. */
int glove_push(glove_t *g, const float row[GLOVE_CHANNELS], glove_output_t *out);

#ifdef __cplusplus
}
#endif
#endif