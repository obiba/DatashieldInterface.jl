module DatashieldInterface

using DataFrames

include("DSObject.jl")
include("utils.jl")

include("datashield_errors.jl")
export datashield_errors, datashield_error_messages

include("DSLoginBuilder.jl")
export DSLoginBuilder, newDSLoginBuilder, build

include("datashield_connections.jl")
export datashield_connections, datashield_connections_default, datashield_connections_find

include("datashield_sessions.jl")
export datashield_sessions

include("datashield_symbol.jl")
export datashield_symbols, datashield_rm

include("datashield_list.jl")
export datashield_tables,
    datashield_resources,
    datashield_workspaces,
    datashield_workspace_save,
    datashield_workspace_restore,
    datashield_workspace_rm

include("datashield_status.jl")
export datashield_profiles,
    datashield_methods,
    datashield_method_status,
    datashield_pkg_status,
    datashield_pkg_check,
    datashield_table_status,
    datashield_resource_status

include("datashield_aggregate.jl")
export datashield_aggregate

include("datashield_assign.jl")
export datashield_assign,
    datashield_assign_table, datashield_assign_resource, datashield_assign_expr

include("datashield_login.jl")
export datashield_login

include("datashield_logout.jl")
export datashield_logout

# DataSHIELD interface generic functions: implementations are provided by the
# downstream packages (e.g. DatashieldOpal), one dedicated module per repository
export DSObject,
    DSDriver,
    DSSession,
    DSConnection,
    DSResult,
    dsConnect,
    dsDisconnect,
    dsKeepAlive,
    dsIsAsync,
    dsHasSession,
    dsSession,
    dsIsReady,
    dsStateMessage,
    dsListTables,
    dsHasTable,
    dsListResources,
    dsHasResource,
    dsListSymbols,
    dsRmSymbol,
    dsListProfiles,
    dsListMethods,
    dsListPackages,
    dsListWorkspaces,
    dsSaveWorkspace,
    dsRestoreWorkspace,
    dsRmWorkspace,
    dsAssignTable,
    dsAssignResource,
    dsAssignExpr,
    dsAggregate,
    dsIsCompleted,
    dsFetch,
    dsGetInfo

export register_driver!, get_driver

end
