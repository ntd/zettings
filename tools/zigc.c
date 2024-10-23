#include <stdio.h>
#include "zigc.h"

void cFunction(Pad24 pad1, Pad24 pad2, Pad24 pad3, Pad24 pad4, Pad24 pad5,
               Pad16 pad6, void *sentinel)
{
    printf("We are inside %s now: sentinel is '%p'!\n", __func__, sentinel);
}
