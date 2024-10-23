typedef struct {
    char padding[24];
} Pad24;

typedef struct {
    char padding[16];
} Pad16;

int cFunction(Pad24 a, Pad24 b, Pad24 c, Pad24 d, Pad24 e, Pad16 f, int sentinel);
