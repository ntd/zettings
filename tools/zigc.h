typedef struct {
    char padding[24];
} Pad24;

typedef struct {
    char padding[16];
} Pad16;

int cFunction(Pad24 pad1, Pad24 pad2, Pad24 pad3, Pad24 pad4, Pad24 pad5,
              Pad16 pad6, int sentinel);
