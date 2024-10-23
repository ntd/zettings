#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

typedef struct {
    size_t length;
    uint8_t *data;
} UA_String;

typedef struct {
    UA_String locale;
    UA_String text;
} UA_LocalizedText;

enum UA_NodeIdType {
    UA_NODEIDTYPE_NUMERIC    = 0,
    UA_NODEIDTYPE_STRING     = 3,
    UA_NODEIDTYPE_GUID       = 4,
    UA_NODEIDTYPE_BYTESTRING = 5
};

typedef struct {
    uint32_t data1;
    uint16_t data2;
    uint16_t data3;
    uint8_t  data4[8];
} UA_Guid;

typedef struct {
    uint16_t namespaceIndex;
    enum UA_NodeIdType identifierType;
    union {
        uint32_t  numeric;
        UA_String string;
        UA_Guid   guid;
        UA_String byteString;
    } identifier;
} UA_NodeId;

typedef enum {
    UA_VARIANT_DATA,
    UA_VARIANT_DATA_NODELETE
} UA_VariantStorageType;

typedef struct {
    const void *type;
    UA_VariantStorageType storageType;
    size_t arrayLength;
    void *data;
    size_t arrayDimensionsSize;
    uint32_t *arrayDimensions;
} UA_Variant;

typedef struct {
    uint32_t specifiedAttributes;
    UA_LocalizedText displayName;
    UA_LocalizedText description;
    uint32_t writeMask;
    uint32_t userWriteMask;
    UA_Variant value;
    UA_NodeId dataType;
    int32_t valueRank;
    size_t arrayDimensionsSize;
    uint32_t *arrayDimensions;
    uint8_t accessLevel;
    uint8_t userAccessLevel;
    double minimumSamplingInterval;
    bool historizing;
} UA_VariableAttributes;

typedef struct {
    uint16_t namespaceIndex;
    UA_String name;
} UA_QualifiedName;

typedef struct {
    uint32_t (*read)(void *server);
    uint32_t (*write)(void * server);
} UA_DataSource;

uint32_t UA_Server_addDataSourceVariableNode(void *server,
                                             const UA_NodeId requestedNewNodeId,
                                             const UA_NodeId parentNodeId,
                                             const UA_NodeId referenceTypeId,
                                             const UA_QualifiedName browseName,
                                             const UA_NodeId typeDefinition,
                                             const UA_VariableAttributes attr,
                                             const UA_DataSource dataSource,
                                             void *nodeContext, UA_NodeId *outNewNodeId);
