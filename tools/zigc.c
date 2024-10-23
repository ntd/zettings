#include "zigc.h"
#include <stdint.h>

int cFunction(Pad24 pad1, Pad24 pad2, Pad24 pad3, Pad24 pad4, Pad24 pad5,
              Pad16 pad6, void *sentinel)
{
    return (int) (uintptr_t) sentinel;
}
