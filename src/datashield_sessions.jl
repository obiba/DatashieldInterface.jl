"""
    datashield_sessions(conns; async=true, success=nothing, error=nothing, errors_print=false)

Ensure that the remote R sessions are up and running during the analysis.

# Arguments
- `conns::Union{DSConnection, Vector{<:DSConnection}}`: Connection object or a vector of connection objects
- `async::Bool=true`: Whether the remote R/DataSHIELD session should be created asynchronously.
  When true (default) the calls are parallelized over the connections, when the connection
  supports that feature, with an extra overhead of requests
- `success::Union{Nothing, Function}=nothing`: Callback function that will be called each time an R session
  has been created from a connection. The expected function signature is the connection/study name
- `error::Union{Nothing, Function}=nothing`: Callback function that will be called each time the R session
  creation request has failed. The expected function signature is the connection/study name and
  the error message
- `errors_print::Bool=false`: Whether to print datashield errors in the console or return a message
  indicating that they can be retrieved using `datashield_errors`
"""
function datashield_sessions(
    conns::Union{DSConnection,Vector{<:DSConnection}};
    async::Bool=true,
    success=nothing,
    error=nothing,
    errors_print::Bool=false,
)
    _clear_last_errors()

    if conns isa Vector{<:DSConnection}
        # filter conns supporting session API and not having connection
        fconns = Dict{String,DSConnection}()
        session_api = Dict{String,Any}()
        for conn in conns
            a = get(dsIsAsync(conn), "session", nothing)
            if !isnothing(a) && !dsHasSession(conn)
                fconns[conn.name] = conn
                session_api[conn.name] = a
            end
        end
        isempty(fconns) && return nothing

        sessions = Dict{String,Any}()
        asyncs = Dict{String,Bool}()
        for (n, conn) in fconns
            asyncs[n] = async && session_api[n] === true
        end
        pb = _newProgress(1 + length(fconns))
        # async first
        for (n, conn) in fconns
            if asyncs[n]
                try
                    sessions[n] = dsSession(conn; async=async)
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
                    _tickProgress(pb; what="Session $(conn.name)")
                    sessions[n] = dsSession(conn; async=false)
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
            messages = String[]
            for (n, conn) in fconns
                if !completed[n]
                    if !_has_last_errors(n)
                        try
                            msg = "$(conn.name): $(dsStateMessage(sessions[n]))"
                            push!(messages, msg)
                            if asyncs[n]
                                completed[n] = dsIsReady(sessions[n])
                                if completed[n]
                                    _tickProgress(pb; what=msg)
                                end
                            else
                                completed[n] = true
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
                    what="Waiting... ($(join(messages, ", ")))",
                )
                sleep(_get_sleep_time(checks))
                checks += 1
            end
        end
        _tickProgress(pb; what="All R sessions ready")
    else
        a = get(dsIsAsync(conns), "session", nothing)
        if !isnothing(a)
            try
                if !dsHasSession(conns)
                    dsSession(conns; async=false)
                end
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
    end
    _handle_errors(errors_print)
    return nothing
end
