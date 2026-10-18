"""
    datashield_connections(; env=Main)

List the connection object lists found in the analytic environment. If there is
only one set of connections, it copies that one set and names the copy
'default.connections', which all subsequent calls to client-side functions will use
by default.

# Arguments
- `env::Module=Main`: The module where to search for the connection symbols.
"""
function datashield_connections(; env::Module=Main)
    found = _get_ds_connections(env)
    if found.flag == 0
        throw(
            ErrorException(
                "Are you logged in to any server? Please provide a valid connection object!"
            ),
        )
    end

    if found.flag == 1
        println(" There is only one set of connection objects available that is:")
        show(found.conns)
        println()
        _STATE[_DEFAULT_CONNECTIONS_KEY] = found.conns
        return println(
            " This set of connection objects has been copied to create 'default.connections',\n which all DataSHIELD functions will now use by default.\n If you want to change the default connection objects,\n please run the function datashield_connections_default() again.",
        )
    end

    if found.flag > 1
        println(
            " There is more than one set of connection objects available, these are: '$(join(found.names, "', '"))'.",
        )
        if "default.connections" in string.(found.names)
            println(" Showing 'default.connections':")
            show(datashield_connections_default())
            println()
        else
            return println(
                " You can either choose to specify the connection objects you wish to use\n for each individual function call using the argument:\n 'connections=name of connection objects'\n or else use the datashield_connections_default() function\n to create the object 'default.connections', which all\n DataSHIELD functions will then use by default.",
            )
        end
    end
    return nothing
end

"""
    datashield_connections_default(; name=nothing)

Set or get the default list of connection objects in the analytic environment.

# Arguments
- `name::Union{Nothing, Symbol}=nothing`: Symbol name that identifies the set of connection objects
  to be used by default. If not provided, the 'default.connections' value is returned.

# Returns
- The 'default.connections' value or nothing if not defined
"""
function datashield_connections_default(;
    name::Union{Nothing,Symbol}=nothing, env::Module=Main
)
    if isnothing(name)
        if haskey(_STATE, _DEFAULT_CONNECTIONS_KEY)
            return _STATE[_DEFAULT_CONNECTIONS_KEY]
        else
            return nothing
        end
    end
    _clear_cache()
    _STATE[_DEFAULT_CONNECTIONS_KEY] = getfield(env, name)
    return nothing
end

"""
    datashield_connections_find(; env=Main)

Search for connection object lists in the analytic environment. If one set of
connection objects is found, it is assigned to 'default.connections'. If more than
one set of connection objects is found and none of them is named
'default.connections', the function stops and suggests using the
`datashield_connections_default` function.

# Arguments
- `env::Module=Main`: The module where to search for the connection symbols.

# Returns
- A set of connection objects
"""
function datashield_connections_find(; env::Module=Main)
    found = _get_ds_connections(env)
    if found.flag == 1
        return found.conns
    elseif found.flag == 0
        throw(
            ErrorException(
                " Are you logged in to any server? Please provide a valid connection object! ",
            ),
        )
    else
        for n in found.names
            if string(n) == "default.connections"
                return getfield(env, n)
            end
        end
        println(
            "More than one list of connection objects were found with no default specified: '$(join(found.names, "', '"))'!",
        )
        throw(
            ErrorException(
                "Please specify a default list of connection objects using datashield_connections_default()",
            ),
        )
    end
end

"""
Search the analytic environment module for connection object lists. The connections
are kept in a vector; if more than one list is found it returns all of them.
"""
function _get_ds_connections(env::Module)
    connlist = Symbol[]
    for sym in names(env; all=true)
        isdefined(env, sym) || continue
        obj = getfield(env, sym)
        if obj isa AbstractVector && !isempty(obj) && _is_ds_connection(obj[1])
            push!(connlist, sym)
        end
    end
    flag = length(connlist)
    if flag == 0
        return (flag=0, names=Symbol[], conns=nothing)
    elseif flag == 1
        return (flag=1, names=connlist, conns=getfield(env, connlist[1]))
    end
    return (flag=flag, names=connlist, conns=nothing)
end
