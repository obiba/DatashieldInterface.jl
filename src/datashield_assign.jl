"""
    datashield_assign(conns, symbol, value; variables=nothing, missings=false, identifiers=nothing, id_name=nothing, async=true, success=nothing, error=nothing)

Assign a table or an expression result to a R symbol in the DataSHIELD R session.
Note that usage of `datashield_assign_table` or `datashield_assign_expr` should be
preferred for readability.

# Arguments
- `conns::Union{DSConnection, Vector{<:DSConnection}}`: Connection object or a vector of connection objects
- `symbol::String`: Name of the R symbol
- `value`: Fully qualified name of a table reference in data repositories OR a R expression
  with allowed assign functions calls
- `variables`: List of variable names or Javascript expression that selects the variables of a table
  (ignored if value does not refer to a table)
- `missings::Bool=false`: If true, missing values will be pushed from data repository to R. Ignored
  if value is an R expression
- `identifiers::Union{Nothing, String}=nothing`: Name of the identifiers mapping to use when
  assigning entities to R (if supported by data repository)
- `id_name::Union{Nothing, String}=nothing`: Name of the column that will contain the entity identifiers
- `async::Bool=true`: Whether the result of the call should be retrieved asynchronously. When true
  (default) the calls are parallelized over the connections, when the connection supports that
  feature, with an extra overhead of requests
- `success::Union{Nothing, Function}=nothing`: Callback function that will be called each time an
  assignment is successful. The expected function signature is the connection/study name
- `error::Union{Nothing, Function}=nothing`: Callback function that will be called each time the
  assignment request has failed. The expected function signature is the connection/study name
  and the error message
"""
function datashield_assign(
    conns::Union{DSConnection,Vector{<:DSConnection}},
    symbol::String,
    value;
    variables=nothing,
    missings=false,
    identifiers=nothing,
    id_name=nothing,
    async::Bool=true,
    success=nothing,
    error=nothing,
)
    _clear_last_errors()
    if value isa Expr
        datashield_assign_expr(
            conns, symbol, value; async=async, success=success, error=error
        )
    else
        datashield_assign_table(
            conns,
            symbol,
            value;
            variables=variables,
            missings=missings,
            identifiers=identifiers,
            id_name=id_name,
            async=async,
            success=success,
            error=error,
        )
    end
end

"""
    datashield_assign_table(conns, symbol, table; variables=nothing, missings=false, identifiers=nothing, id_name=nothing, async=true, success=nothing, error=nothing, errors_print=false)

Assign a table to a R symbol in the DataSHIELD R session.

# Arguments
- `conns::Union{DSConnection, Vector{<:DSConnection}}`: Connection object or a vector of connection objects
- `symbol::String`: Name of the R symbol
- `table`: Fully qualified name of a table in the data repository (can be a string, a vector of strings,
  a dictionary keyed by server name, or a data frame with 'server' and 'table' columns)
- `variables`: List of variable names or Javascript expression that selects the variables of a table
- `missings::Bool=false`: If true, missing values will be pushed from data repository to R
- `identifiers::Union{Nothing, String}=nothing`: Name of the identifiers mapping to use when
  assigning entities to R (if supported by the data repository)
- `id_name::Union{Nothing, String}=nothing`: Name of the column that will contain the entity identifiers
- `async::Bool=true`: Whether the result of the call should be retrieved asynchronously. When true
  (default) the calls are parallelized over the connections, when the connection supports that
  feature, with an extra overhead of requests
- `success::Union{Nothing, Function}=nothing`: Callback function that will be called each time an
  assignment is successful. The expected function signature is the connection/study name
- `error::Union{Nothing, Function}=nothing`: Callback function that will be called each time the
  assignment request has failed. The expected function signature is the connection/study name
  and the error message
- `errors_print::Bool=false`: Whether to print datashield errors in the console or return a message
  indicating that they can be retrieved using `datashield_errors`
"""
function datashield_assign_table(
    conns::Union{DSConnection,Vector{<:DSConnection}},
    symbol::String,
    table;
    variables=nothing,
    missings=false,
    identifiers=nothing,
    id_name=nothing,
    async::Bool=true,
    success=nothing,
    error=nothing,
    errors_print::Bool=false,
)
    datashield_sessions(conns)
    _clear_last_errors()
    if isnothing(table) || (table isa AbstractVector && isempty(table))
        throw(ErrorException("Not a valid table name"))
    end

    # prepare tables as a named dictionary
    tables = _as_named_list_of_values(conns, table; colname="table")

    if conns isa Vector{<:DSConnection}
        # filter connections to assign
        fconns = _filter_connections_by_name(
            _as_named_list_of_connections(conns), collect(keys(tables))
        )

        results = Dict{String,Any}()
        asyncs = Dict{String,Bool}()
        for (n, conn) in fconns
            asyncs[n] = async ? get(dsIsAsync(conn), "assignTable", false) : false
        end
        pb = _newProgress(1 + length(fconns))
        # async first
        for (n, conn) in fconns
            if asyncs[n]
                try
                    results[n] = dsAssignTable(
                        conn,
                        symbol,
                        string(tables[n]);
                        variables=variables,
                        missings=missings,
                        identifiers=identifiers,
                        id_name=id_name,
                        async=true,
                    )
                catch e
                    _append_error(n, _condition_message(e))
                    if _is_callback(error)
                        error(n, _condition_message(e))
                    end
                end
            end
        end
        # not async (blocking calls)
        for (n, conn) in fconns
            if !asyncs[n]
                try
                    _tickProgress(
                        pb; what="Assigning $(conn.name) ($symbol <- `$(tables[n])`)"
                    )
                    results[n] = dsAssignTable(
                        conn,
                        symbol,
                        string(tables[n]);
                        variables=variables,
                        missings=missings,
                        identifiers=identifiers,
                        id_name=id_name,
                        async=false,
                    )
                catch e
                    _append_error(n, _condition_message(e))
                    if _is_callback(error)
                        error(n, _condition_message(e))
                    end
                end
            end
        end
        # polling
        completed = Dict{String,Bool}(n => false for n in keys(fconns))
        checks = 1
        while !all(values(completed))
            for (n, conn) in fconns
                if !completed[n]
                    if !_has_last_errors(n)
                        try
                            _updateProgress(
                                pb;
                                step=count(values(completed)),
                                total=length(fconns),
                                what="Checking $(conn.name) ($symbol <- `$(tables[n])`)",
                            )
                            if asyncs[n]
                                completed[n] = dsIsCompleted(results[n])
                                if completed[n]
                                    _tickProgress(
                                        pb;
                                        what="Finalizing assignment $(conn.name) ($symbol <- `$(tables[n])`)",
                                    )
                                    dsFetch(results[n])
                                end
                            else
                                completed[n] = true
                                _tickProgress(
                                    pb;
                                    what="Finalizing assignment $(conn.name) ($symbol <- `$(tables[n])`)",
                                )
                                dsFetch(results[n])
                            end
                            if completed[n] && _is_callback(success)
                                success(n)
                            end
                        catch e
                            _append_error(n, _condition_message(e))
                            completed[n] = true
                            if _is_callback(error)
                                error(n, _condition_message(e))
                            end
                        end
                    else
                        completed[n] = true
                    end
                else
                    # heart beat request
                    dsKeepAlive(conn)
                end
            end
            if !all(values(completed))
                _updateProgress(
                    pb;
                    step=count(values(completed)),
                    total=length(fconns),
                    what="Waiting... ($symbol <- ...)",
                )
                sleep(_get_sleep_time(checks))
                checks += 1
            end
        end
        _tickProgress(pb; what="Assigned all table ($symbol <- ...)")
    else
        try
            res = dsAssignTable(
                conns,
                symbol,
                string(tables[conns.name]);
                variables=variables,
                missings=missings,
                identifiers=identifiers,
                id_name=id_name,
            )
            dsGetInfo(res)
            dsFetch(res)
            if _is_callback(success)
                success(conns.name)
            end
        catch e
            _append_error(conns.name, _condition_message(e))
            if _is_callback(error)
                error(conns.name, _condition_message(e))
            end
        end
    end
    _handle_errors(errors_print)
    return nothing
end
"""
    datashield_assign_resource(conns, symbol, resource; async=true, success=nothing, error=nothing, errors_print=false)

Assign a resource to a R symbol in the DataSHIELD R session.

# Arguments
- `conns::Union{DSConnection, Vector{<:DSConnection}}`: Connection object or a vector of connection objects
- `symbol::String`: Name of the R symbol
- `resource`: Fully qualified name of a resource reference in the data repository (can be a string, a
  vector of strings, a dictionary keyed by server name, or a data frame with 'server' and 'resource'
  columns)
- `async::Bool=true`: Whether the result of the call should be retrieved asynchronously. When true
  (default) the calls are parallelized over the connections, when the connection supports that
  feature, with an extra overhead of requests
- `success::Union{Nothing, Function}=nothing`: Callback function that will be called each time an
  assignment is successful. The expected function signature is the connection/study name
- `error::Union{Nothing, Function}=nothing`: Callback function that will be called each time the
  assignment request has failed. The expected function signature is the connection/study name
  and the error message
- `errors_print::Bool=false`: Whether to print datashield errors in the console or return a message
  indicating that they can be retrieved using `datashield_errors`
"""
function datashield_assign_resource(
    conns::Union{DSConnection,Vector{<:DSConnection}},
    symbol::String,
    resource;
    async::Bool=true,
    success=nothing,
    error=nothing,
    errors_print::Bool=false,
)
    datashield_sessions(conns)
    _clear_last_errors()
    if isnothing(resource) || (resource isa AbstractVector && isempty(resource))
        throw(ErrorException("Not a valid resource name"))
    end

    # prepare resources as a named dictionary
    resources = _as_named_list_of_values(conns, resource; colname="resource")

    if conns isa Vector{<:DSConnection}
        # filter connections to assign
        fconns = _filter_connections_by_name(
            _as_named_list_of_connections(conns), collect(keys(resources))
        )

        results = Dict{String,Any}()
        asyncs = Dict{String,Bool}()
        for (n, conn) in fconns
            asyncs[n] = async ? get(dsIsAsync(conn), "assignResource", false) : false
        end
        pb = _newProgress(1 + length(fconns))
        # async first
        for (n, conn) in fconns
            if asyncs[n]
                try
                    results[n] = dsAssignResource(
                        conn, symbol, string(resources[n]); async=true
                    )
                catch e
                    _append_error(n, _condition_message(e))
                    if _is_callback(error)
                        error(n, _condition_message(e))
                    end
                end
            end
        end
        # not async (blocking calls)
        for (n, conn) in fconns
            if !asyncs[n]
                try
                    _tickProgress(
                        pb; what="Assigning $(conn.name) ($symbol <- `$(resources[n])`)"
                    )
                    results[n] = dsAssignResource(
                        conn, symbol, string(resources[n]); async=false
                    )
                catch e
                    _append_error(n, _condition_message(e))
                    if _is_callback(error)
                        error(n, _condition_message(e))
                    end
                end
            end
        end
        # polling
        completed = Dict{String,Bool}(n => false for n in keys(fconns))
        checks = 1
        while !all(values(completed))
            for (n, conn) in fconns
                if !completed[n]
                    if !_has_last_errors(n)
                        try
                            _updateProgress(
                                pb;
                                step=count(values(completed)),
                                total=length(fconns),
                                what="Checking $(conn.name) ($symbol <- `$(resources[n])`)",
                            )
                            if asyncs[n]
                                completed[n] = dsIsCompleted(results[n])
                                if completed[n]
                                    _tickProgress(
                                        pb;
                                        what="Finalizing assignment $(conn.name) ($symbol <- `$(resources[n])`)",
                                    )
                                    dsFetch(results[n])
                                end
                            else
                                completed[n] = true
                                _tickProgress(
                                    pb;
                                    what="Finalizing assignment $(conn.name) ($symbol <- `$(resources[n])`)",
                                )
                                dsFetch(results[n])
                            end
                            if completed[n] && _is_callback(success)
                                success(n)
                            end
                        catch e
                            _append_error(n, _condition_message(e))
                            completed[n] = true
                            if _is_callback(error)
                                error(n, _condition_message(e))
                            end
                        end
                    else
                        completed[n] = true
                    end
                else
                    # heart beat request
                    dsKeepAlive(conn)
                end
            end
            if !all(values(completed))
                _updateProgress(
                    pb;
                    step=count(values(completed)),
                    total=length(fconns),
                    what="Waiting... ($symbol <- ...)",
                )
                sleep(_get_sleep_time(checks))
                checks += 1
            end
        end
        _tickProgress(pb; what="Assigned all resource ($symbol <- ...)")
    else
        try
            res = dsAssignResource(conns, symbol, string(resources[conns.name]))
            dsGetInfo(res)
            dsFetch(res)
            if _is_callback(success)
                success(conns.name)
            end
        catch e
            _append_error(conns.name, _condition_message(e))
            if _is_callback(error)
                error(conns.name, _condition_message(e))
            end
        end
    end
    _handle_errors(errors_print)
    return nothing
end

"""
    datashield_assign_expr(conns, symbol, expr; async=true, success=nothing, error=nothing, errors_print=false)

Assign the result of the execution of an expression to a R symbol in the DataSHIELD
R session.

# Arguments
- `conns::Union{DSConnection, Vector{<:DSConnection}}`: Connection object or a vector of connection objects
- `symbol::String`: Name of the R symbol
- `expr`: R expression with allowed assign functions calls, or a dictionary of expressions keyed
  by connection name
- `async::Bool=true`: Whether the result of the call should be retrieved asynchronously. When true
  (default) the calls are parallelized over the connections, when the connection supports that
  feature, with an extra overhead of requests
- `success::Union{Nothing, Function}=nothing`: Callback function that will be called each time an
  assignment is successful. The expected function signature is the connection/study name
- `error::Union{Nothing, Function}=nothing`: Callback function that will be called each time the
  assignment request has failed. The expected function signature is the connection/study name
  and the error message
- `errors_print::Bool=false`: Whether to print datashield errors in the console or return a message
  indicating that they can be retrieved using `datashield_errors`
"""
function datashield_assign_expr(
    conns::Union{DSConnection,Vector{<:DSConnection}},
    symbol::String,
    expr;
    async::Bool=true,
    success=nothing,
    error=nothing,
    errors_print::Bool=false,
)
    datashield_sessions(conns)
    _clear_last_errors()

    # prepare expressions as a named dictionary
    exprs = _as_named_list_of_values(conns, expr)

    if conns isa Vector{<:DSConnection}
        # filter connections to assign
        fconns = _filter_connections_by_name(
            _as_named_list_of_connections(conns), collect(keys(exprs))
        )

        results = Dict{String,Any}()
        asyncs = Dict{String,Bool}()
        for (n, conn) in fconns
            asyncs[n] = async ? get(dsIsAsync(conn), "assignExpr", false) : false
        end
        pb = _newProgress(1 + length(fconns))
        # async first
        for (n, conn) in fconns
            if asyncs[n]
                try
                    results[n] = dsAssignExpr(conn, symbol, exprs[n]; async=true)
                catch e
                    _append_error(n, _condition_message(e))
                    if _is_callback(error)
                        error(n, _condition_message(e))
                    end
                end
            end
        end
        # not async (blocking calls)
        for (n, conn) in fconns
            if !asyncs[n]
                try
                    _tickProgress(
                        pb;
                        what="Assigning expr. $(conn.name) ($symbol <- $(_deparse(exprs[n])))",
                    )
                    results[n] = dsAssignExpr(conn, symbol, exprs[n]; async=false)
                catch e
                    _append_error(n, _condition_message(e))
                    if _is_callback(error)
                        error(n, _condition_message(e))
                    end
                end
            end
        end
        # polling
        completed = Dict{String,Bool}(n => false for n in keys(fconns))
        checks = 1
        while !all(values(completed))
            for (n, conn) in fconns
                dexpr = _deparse(exprs[n])
                if !completed[n]
                    if !_has_last_errors(n)
                        try
                            _updateProgress(
                                pb;
                                step=count(values(completed)),
                                total=length(fconns),
                                what="Checking $(conn.name) ($symbol <- $dexpr)",
                            )
                            if asyncs[n]
                                completed[n] = dsIsCompleted(results[n])
                                if completed[n]
                                    _tickProgress(
                                        pb;
                                        what="Finalizing assignment $(conn.name) ($symbol <- $dexpr)",
                                    )
                                    dsFetch(results[n])
                                end
                            else
                                completed[n] = true
                                _tickProgress(
                                    pb;
                                    what="Finalizing assignment $(conn.name) ($symbol <- $dexpr)",
                                )
                                dsFetch(results[n])
                            end
                            if completed[n] && _is_callback(success)
                                success(n)
                            end
                        catch e
                            _append_error(n, _condition_message(e))
                            completed[n] = true
                            if _is_callback(error)
                                error(n, _condition_message(e))
                            end
                        end
                    else
                        completed[n] = true
                    end
                else
                    # heart beat request
                    dsKeepAlive(conn)
                end
            end
            if !all(values(completed))
                _updateProgress(
                    pb;
                    step=count(values(completed)),
                    total=length(fconns),
                    what="Waiting... ($symbol <- $(_deparse(expr)))",
                )
                sleep(_get_sleep_time(checks))
                checks += 1
            end
        end
        _tickProgress(pb; what="Assigned expr. ($symbol <- $(_deparse(expr)))")
    else
        try
            res = dsAssignExpr(conns, symbol, exprs[conns.name])
            dsFetch(res)
            if _is_callback(success)
                success(conns.name)
            end
        catch e
            _append_error(conns.name, _condition_message(e))
            if _is_callback(error)
                error(conns.name, _condition_message(e))
            end
        end
    end
    _handle_errors(errors_print)
    return nothing
end
