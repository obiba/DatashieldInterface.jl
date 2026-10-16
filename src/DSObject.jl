"""
    DSObject

Abstract base type for all DataSHIELD classes (e.g., drivers, connections).
This is an abstract type: no objects may be created from it.

More generally, DataSHIELD defines a very small set of abstract types and
generic functions so that clients can perform analyses over the
DataSHIELD implementations.
"""
abstract type DSObject end

"""
    DSDriver

Abstract base type for all DataSHIELD-aware data repositories drivers
(e.g., Opal, ...). The `DSDriver` type defines the operations for creating
connections.
"""
abstract type DSDriver <: DSObject end

"""
    DSSession

Abstract type describing the state of the R session.
"""
abstract type DSSession <: DSObject end

"""
    DSConnection

Abstract type for instances of a connection to a DataSHIELD-aware
data repository.
"""
abstract type DSConnection <: DSObject end

"""
    DSResult

Abstract type for the result of a DataSHIELD operation.
"""
abstract type DSResult <: DSObject end

"""
    dsConnect(drv, name; restore, ...) -> DSConnection

Create a connection to a DataSHIELD-aware data repository, going through the
appropriate authentication procedure. Some implementations may allow to
have multiple connections open, so this function may be invoked repeatedly
assigning its output to different objects.

The authentication mechanism is left unspecified: check the documentation of
individual drivers for details.

# Arguments
- `drv::DSDriver`: An object inheriting from `DSDriver`
- `name::String`: Name of the connection, which must be unique among all the DataSHIELD connections
- `restore::Union{Nothing, String}=nothing`: Workspace name to be restored in the newly created DataSHIELD R session
"""
function dsConnect end

"""
    dsDisconnect(conn; save=nothing)

Disconnect from a data repository and clear the session.

# Arguments
- `conn::DSConnection`: An object inheriting from `DSConnection`
- `save::Union{Nothing, String}=nothing`: Name of the workspace to save. Note that if a DataSHIELD R
  session is present, it will be closed
"""
function dsDisconnect end

"""
    dsKeepAlive(conn)

Keep the DataSHIELD R session alive (heart beat request).
"""
function dsKeepAlive end

"""
    dsIsAsync(conn) -> Dict

Get whether the calls are async or not.

# Returns
- A dictionary with keys "session", "aggregate", "assignTable", "assignResource", "assignExpr"
  mapped to `Bool` values
"""
function dsIsAsync end

"""
    dsHasSession(conn) -> Bool

Get whether the connection has a DataSHIELD session.
"""
function dsHasSession end

"""
    dsSession(conn; async=true) -> DSSession

Get the DataSHIELD session object starting on demand the DataSHIELD R server.

# Arguments
- `conn::DSConnection`: An object inheriting from `DSConnection`
- `async::Bool=true`: Avoid blocking for session creation
"""
function dsSession end

"""
    dsIsReady(session) -> Bool

Get whether the remote R session is up and running, ready to accept R commands.
The primary use of this function is to know whether the session is ready after it
has been created in an asynchronous way.
"""
function dsIsReady end

"""
    dsStateMessage(session) -> String

Get a human-readable message that informs about the state of the remote R session.
The primary use of this function is to inform the user about the session state
process after it has been created in an asynchronous way.
"""
function dsStateMessage end

"""
    dsListTables(conn) -> Vector{String}

List defined tables, visible to the caller, in the data repository. The returned
table names can be used when performing DataSHIELD table assignments.
"""
function dsListTables end

"""
    dsHasTable(conn, table) -> Bool

Get whether a table with the provided name can be accessible for performing
DataSHIELD table assignments.
"""
function dsHasTable end

"""
    dsListResources(conn) -> Vector{String}

List defined resources, visible to the caller, in the data repository. The returned
resource names can be used when performing DataSHIELD resource assignments.
"""
function dsListResources end

"""
    dsHasResource(conn, resource) -> Bool

Get whether a resource with the provided name can be accessible for performing
DataSHIELD resource assignments.
"""
function dsHasResource end

"""
    dsListSymbols(conn) -> Vector{String}

List the R symbols available in the DataSHIELD R session.
"""
function dsListSymbols end

"""
    dsRmSymbol(conn, symbol)

Remove the R symbol with the provided name from the DataSHIELD R session.
"""
function dsRmSymbol end

"""
    dsListProfiles(conn) -> Dict

List available DataSHIELD profiles in the data repository, and profile currently
applied to the connection.

# Returns
- A dictionary with keys "available" and "current"
"""
function dsListProfiles end

"""
    dsListMethods(conn; type="aggregate") -> DataFrame

List the DataSHIELD methods (aggregate or assign) available in the data repository.

# Arguments
- `conn::DSConnection`: An object inheriting from `DSConnection`
- `type::String="aggregate"`: Type of the method: "aggregate" (default) or "assign"

# Returns
- Data frame with columns: name, type, class, value, package, version
"""
function dsListMethods end

"""
    dsListPackages(conn) -> DataFrame

List the R packages available for the DataSHIELD functionality in the data repository.
"""
function dsListPackages end

"""
    dsListWorkspaces(conn) -> DataFrame

List the DataSHIELD R workspaces saved by the current user in the data repository.
"""
function dsListWorkspaces end

"""
    dsSaveWorkspace(conn, name)

Save the DataSHIELD R session to a workspace with the provided name
in the data repository.
"""
function dsSaveWorkspace end

"""
    dsRestoreWorkspace(conn, name)

Restore a previously saved DataSHIELD R session (the workspace saved with
`dsSaveWorkspace`) with the provided name from the data repository. Note that
when restoring a workspace, any existing symbol or file with same name will
be overridden.
"""
function dsRestoreWorkspace end

"""
    dsRmWorkspace(conn, name)

Remove the workspace with the provided name from the data repository.
"""
function dsRmWorkspace end

"""
    dsAssignTable(conn, symbol, table; variables, missings, identifiers, id_name, async=true) -> DSResult

Assign a table to a R symbol in the DataSHIELD R session.

# Arguments
- `conn::DSConnection`: An object inheriting from `DSConnection`
- `symbol::String`: Symbol name
- `table::String`: Fully qualified name of a table in the data repository
- `variables::Union{Nothing, String, Vector{String}}=nothing`: List of variable names or Javascript
  expression that selects the variables of a table
- `missings::Bool=false`: If true, missing values will be pushed from data repository to R
- `identifiers::Union{Nothing, String}=nothing`: Name of the identifiers mapping to use when
  assigning entities to R (if supported by data repository)
- `id_name::Union{Nothing, String}=nothing`: Name of the column that will contain the entity
  identifiers. If not specified, the identifiers will be the data frame row names
- `async::Bool=true`: Whether the result of the call should be retrieved asynchronously
"""
function dsAssignTable end

"""
    dsAssignResource(conn, symbol, resource; async=true) -> DSResult

Assign a resource to a R symbol in the DataSHIELD R session.

# Arguments
- `conn::DSConnection`: An object inheriting from `DSConnection`
- `symbol::String`: Symbol name
- `resource::String`: Fully qualified name of a resource in the data repository
- `async::Bool=true`: Whether the result of the call should be retrieved asynchronously
"""
function dsAssignResource end

"""
    dsAssignExpr(conn, symbol, expr; async=true) -> DSResult

Assign the result of the execution of an expression to a R symbol in the DataSHIELD
R session.

# Arguments
- `conn::DSConnection`: An object inheriting from `DSConnection`
- `symbol::String`: Symbol name
- `expr`: R expression with allowed assign functions calls
- `async::Bool=true`: Whether the result of the call should be retrieved asynchronously
"""
function dsAssignExpr end

"""
    dsAggregate(conn, expr; async=true) -> DSResult

Aggregates the expression result using the specified aggregation method in the
DataSHIELD R session.

# Arguments
- `conn::DSConnection`: An object inheriting from `DSConnection`
- `expr`: R expression with allowed aggregate functions calls
- `async::Bool=true`: Whether the result of the call should be retrieved asynchronously
"""
function dsAggregate end

"""
    dsIsCompleted(res) -> Bool

Get whether some DataSHIELD operation is completed. A completed operation implies
that its result can be fetched. This also applies to an operation that has failed.
Always true for a synchronous operation.
"""
function dsIsCompleted end

"""
    dsFetch(res)

Fetch the result of a DataSHIELD operation.
"""
function dsFetch end

"""
    dsGetInfo(dsObj) -> Dict

Get DataSHIELD-aware data repository metadata.
"""
function dsGetInfo end
