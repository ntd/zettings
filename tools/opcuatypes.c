/* cc -o opcuatypes opcuatypes.c $(pkg-config --cflags --libs open62541) */

#include <open62541/server.h>
#include <stdint.h>
#include <stdio.h>

static void dump(const void *buffer, size_t size)
{
    const uint8_t *ptr = buffer;
    printf("%d bytes: ", (int) size);
    while (size--) {
        printf("%02X ", *ptr);
        ++ptr;
    }
    printf("\n");
}

int main()
{
    /* struct UA_DataType {
     * #ifdef UA_ENABLE_TYPEDESCRIPTION
     *      const char *typeName;
     * #endif
     *      UA_NodeId typeId;
     *      UA_NodeId binaryEncodingId;
     *      //UA_NodeId xmlEncodingId;
     *      UA_UInt32 memSize     : 16;
     *      UA_UInt32 typeKind    : 6;
     *      UA_UInt32 pointerFree : 1;
     *      UA_UInt32 overlayable : 1;
     *      UA_UInt32 membersSize : 8;
     *      UA_DataTypeMember *members;
     * }; */
    UA_DataType dt = { 0 };
    dt.typeName = (const char *) 0x89ABCDEF;
    dt.memSize = 0x1234;
    dt.typeKind = 10;
    dt.overlayable = 1;
    dt.membersSize = 0x56;
    dt.members = (void *) 0xFEDCBA98;
    /* Result on my system (x86_64-pc-linux-gnu):
     * 72 bytes: EF CD AB 89 00 00 00 00 00 00 00 00 00 00 00 00
     *           00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
     *           00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
     *           00 00 00 00 00 00 00 00 34 12 8A 56 00 00 00 00
     *           98 BA DC FE 00 00 00 00 */
    dump(&dt, sizeof(dt));

    /* typedef struct {
     *     UA_Variant    value;
     *     UA_DateTime   sourceTimestamp;
     *     UA_DateTime   serverTimestamp;
     *     UA_UInt16     sourcePicoseconds;
     *     UA_UInt16     serverPicoseconds;
     *     UA_StatusCode status;
     *     UA_Boolean    hasValue             : 1;
     *     UA_Boolean    hasStatus            : 1;
     *     UA_Boolean    hasSourceTimestamp   : 1;
     *     UA_Boolean    hasServerTimestamp   : 1;
     *     UA_Boolean    hasSourcePicoseconds : 1;
     *     UA_Boolean    hasServerPicoseconds : 1;
     * } UA_DataValue; */
    UA_DataValue dv = { 0 };
    dv.sourceTimestamp = 0x123456789ABCDEF0;
    dv.serverTimestamp = 0x0102030405060708;
    dv.sourcePicoseconds = 0x1234;
    dv.serverPicoseconds = 0x5678;
    dv.status = 0x09ABCDEF;
    dv.hasStatus = 1;
    dv.hasServerTimestamp = 1;
    dv.hasSourcePicoseconds = 1;
    /* Result on my system (x86_64-pc-linux-gnu):
     * 80 bytes: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
     *           00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
     *           00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
     *           F0 DE BC 9A 78 56 34 12 08 07 06 05 04 03 02 01
     *           34 12 78 56 EF CD AB 09 1A 00 00 00 00 00 00 00 */
    dump(&dv, sizeof(dv));

    return 0;
}
