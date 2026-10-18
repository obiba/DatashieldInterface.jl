"""
    datashield_logout(conns; save=nothing)

Clear the DataSHIELD R sessions and logout from DataSHIELD data repositories.

# Arguments
- `conns::Union{DSConnection, Vector{<:DSConnection}}`: Connection object or a vector of connection objects
- `save::Union{Nothing, String}=nothing`: Save datashield sessions on each DataSHIELD data repository
  (if feature is supported) with provided ID (must be a character string)
"""
function datashield_logout(
    conns::Union{Nothing,DSConnection,Vector{<:DSConnection}};
    save::Union{Nothing,String}=nothing,
)
    _clear_last_errors()
    if conns isa Vector{<:DSConnection}
        pb = _newProgress(1 + length(conns))
        for conn in conns
            _tickProgress(pb; what="Logout $(conn.name)")
            datashield_logout(conn; save=save)
        end
        _tickProgress(pb; what="Logged out from all servers")
    elseif !isnothing(conns)
        saveId = save
        if !isnothing(save)
            saveId = "$(conns.name):$(save)"
        end
        try
            dsDisconnect(conns; save=saveId)
        catch
            # Ignore errors
        end
    end
    _clear_cache()
    return nothing
end
