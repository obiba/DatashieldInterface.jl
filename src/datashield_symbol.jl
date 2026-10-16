"""
    datashield_symbols(conns)

List R symbols. Get the R symbols available after the datashield_assign calls in
the DataSHIELD R session.

# Arguments
- `conns::Union{DSConnection, Vector{<:DSConnection}}`: Connection object or a vector of connection objects

# Returns
- The symbols available in each DataSHIELD R session
"""
function datashield_symbols(conns::Union{DSConnection,Vector{<:DSConnection}})
    datashield_sessions(conns)
    if conns isa Vector{<:DSConnection}
        return Dict{String,Any}(conn.name => datashield_symbols(conn) for conn in conns)
    else
        return dsListSymbols(conns)
    end
end

"""
    datashield_rm(conns, symbol)

Remove a R symbol from the current DataSHIELD session.

# Arguments
- `conns::Union{DSConnection, Vector{<:DSConnection}}`: Connection object or a vector of connection objects
- `symbol::String`: Name of the R symbol
"""
function datashield_rm(conns::Union{DSConnection,Vector{<:DSConnection}}, symbol::String)
    if conns isa Vector{<:DSConnection}
        for conn in conns
            datashield_rm(conn, symbol)
        end
    else
        dsRmSymbol(conns, symbol)
    end
    return nothing
end
