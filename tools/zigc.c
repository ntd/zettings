#include <stdio.h>
#include "zigc.h"

uint32_t UA_Server_addDataSourceVariableNode(void *server,
                                             const UA_NodeId requestedNewNodeId,
                                             const UA_NodeId parentNodeId,
                                             const UA_NodeId referenceTypeId,
                                             const UA_QualifiedName browseName,
                                             const UA_NodeId typeDefinition,
                                             const UA_VariableAttributes attr,
                                             const UA_DataSource dataSource,
                                             void *nodeContext, UA_NodeId *outNewNodeId)
{
    printf("We are inside %s now!\n", __func__);
    return 0;
}
