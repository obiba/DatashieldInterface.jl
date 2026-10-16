"""
    datashield_aggregate(conns, expr; async=true, success=nothing, error=nothing, errors_print=false)

Aggregates the expression result using the specified aggregation method in the
current DataSHIELD session.

# Arguments
- `conns::Union{DSConnection, Vector{<:DSConnection}}`: Connection object or a vector of connection objects
- `expr`: R expression to evaluate, or a dictionary of expressions keyed by connection name
- `async::Bool=true`: Whether the result of the call should be retrieved asynchronously. When true
  (default) the calls are parallelized over the connections, when the connection supports that
  feature, with an extra overhead of requests
- `success::Union{Nothing, Function}=nothing`: Callback function that will be called each time an
  aggregation result is received from a connection. The expected function signature is the
  connection/study name and the result value
- `error::Union{Nothing, Function}=nothing`: Callback function that will be called each time the
  aggregation request has failed. The expected function signature is the connection/study name
  and the error message
- `errors_print::Bool=false`: Whether to print datashield errors in the console or return a message
  indicating that they can be retrieved using `datashield_errors`

# Returns
- The result of the aggregation from each connection
"""
function datashield_aggregate(
    conns::Union{DSConnection,Vector{<:DSConnection}},
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
        # filter connections to aggregate
        fconns = _filter_connections_by_name(
            _as_named_list_of_connections(conns), collect(keys(exprs))
        )

        results = Dict{String,Any}()
        asyncs = Dict{String,Bool}()
        for (n, conn) in fconns
            asyncs[n] = async ? get(dsIsAsync(conn), "aggregate", false) : false
        end
        pb = _newProgress(1 + length(fconns))
        # async first
        for (n, conn) in fconns
            if asyncs[n]
                try
                    results[n] = dsAggregate(conn, exprs[n]; async=true)
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
                        pb; what="Aggregating $(conn.name) ($(_deparse(exprs[n])))"
                    )
                    results[n] = dsAggregate(conn, exprs[n]; async=false)
                catch e
                    _append_error(n, _condition_message(e))
                    if _is_callback(error)
                        error(n, _condition_message(e))
                    end
                end
            end
        end
        # polling
        rval = Dict{String,Any}(n => nothing for n in keys(fconns))
        completed = Dict{String,Bool}(n => false for n in keys(fconns))
        checks = 1
        while !all(values(completed))
            for (n, conn) in fconns
                dexpr = _deparse(exprs[n])
                if !completed[n]
                    try
                        if !_has_last_errors(n)
                            _updateProgress(
                                pb;
                                step=count(values(completed)),
                                total=length(fconns),
                                what="Checking $(conn.name) ($dexpr)",
                            )
                            if asyncs[n]
                                completed[n] = dsIsCompleted(results[n])
                                if completed[n]
                                    _tickProgress(
                                        pb; what="Getting aggregate $(conn.name) ($dexpr)"
                                    )
                                    rval[n] = dsFetch(results[n])
                                    if _is_callback(success)
                                        success(n, rval[n])
                                    end
                                end
                            else
                                completed[n] = true
                                _tickProgress(
                                    pb; what="Getting aggregate $(conn.name) ($dexpr)"
                                )
                                rval[n] = dsFetch(results[n])
                                if _is_callback(success)
                                    success(n, rval[n])
                                end
                            end
                        else
                            completed[n] = true
                            rval[n] = nothing
                        end
                    catch e
                        _append_error(n, _condition_message(e))
                        completed[n] = true
                        rval[n] = nothing
                        if _is_callback(error)
                            error(n, _condition_message(e))
                        end
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
                    what="Waiting... ($(_deparse(expr)))",
                )
                sleep(_get_sleep_time(checks))
                checks += 1
            end
        end
        _tickProgress(pb; what="Aggregated ($(_deparse(expr)))")
    else
        rval = nothing
        try
            res = dsAggregate(conns, exprs[conns.name])
            rval = dsFetch(res)
        catch e
            _append_error(conns.name, _condition_message(e))
            if _is_callback(error)
                error(conns.name, _condition_message(e))
            end
            rval = nothing
        end
        if _is_callback(success) && !_has_last_errors(conns.name)
            success(conns.name, rval)
        end
    end
    _handle_errors(errors_print)
    return rval
end
