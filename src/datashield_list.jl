"""
    datashield_tables(conns)

Get the list of all the tables from the different data repositories.

# Arguments
- `conns::Union{DSConnection, Vector{<:DSConnection}}`: Connection object or a vector of connection objects

# Returns
- Table unique names from all the servers
"""
function datashield_tables(conns::Union{DSConnection,Vector{<:DSConnection}})
    if conns isa Vector{<:DSConnection}
        return Dict{String,Any}(conn.name => dsListTables(conn) for conn in conns)
    else
        return dsListTables(conns)
    end
end

"""
    datashield_resources(conns)

Get the list of all the resources from the different data repositories.

# Arguments
- `conns::Union{DSConnection, Vector{<:DSConnection}}`: Connection object or a vector of connection objects

# Returns
- Resource unique names from all the servers
"""
function datashield_resources(conns::Union{DSConnection,Vector{<:DSConnection}})
    if conns isa Vector{<:DSConnection}
        return Dict{String,Any}(conn.name => dsListResources(conn) for conn in conns)
    else
        return dsListResources(conns)
    end
end

"""
    datashield_workspaces(conns)

Get the list of R workspaces that were saved during a DataSHIELD R session.

# Arguments
- `conns::Union{DSConnection, Vector{<:DSConnection}}`: Connection object or a vector of connection objects

# Returns
- Workspaces details from all the servers
"""
function datashield_workspaces(conns::Union{DSConnection,Vector{<:DSConnection}})
    if conns isa Vector{<:DSConnection}
        res = Dict{String,Any}(conn.name => dsListWorkspaces(conn) for conn in conns)
        server = String[]
        name = String[]
        user = String[]
        lastAccessDate = String[]
        sizes = Int[]
        for n in keys(res)
            wss = res[n]
            if !isnothing(wss) && !isempty(wss)
                append!(server, fill(n, size(wss, 1)))
                append!(name, wss.name)
                append!(user, wss.user)
                append!(lastAccessDate, wss.lastAccessDate)
                append!(sizes, wss.size)
            end
        end
        if !isempty(server)
            return DataFrame(;
                server=server,
                name=name,
                user=user,
                lastAccessDate=lastAccessDate,
                size=sizes,
            )
        else
            return DataFrame()
        end
    else
        return dsListWorkspaces(conns)
    end
end

"""
    datashield_workspace_save(conns, ws)

Save the current state of the DataSHIELD R session in a workspace with the provided
name in each data repository. The workspace can be restored on the next
`datashield_login` or with `datashield_workspace_restore`.

# Arguments
- `conns::Union{DSConnection, Vector{<:DSConnection}}`: Connection object or a vector of connection objects
- `ws::String`: The workspace name
"""
function datashield_workspace_save(
    conns::Union{DSConnection,Vector{<:DSConnection}}, ws::String
)
    datashield_sessions(conns)
    if conns isa Vector{<:DSConnection}
        for conn in conns
            datashield_workspace_save(conn, ws)
        end
    else
        name = "$(conns.name):$(ws)"
        dsSaveWorkspace(conns, name)
    end
    return nothing
end

"""
    datashield_workspace_restore(conns, ws)

Restore the state of a previously saved DataSHIELD R session (the workspace saved
with `datashield_workspace_save`) with the provided name from each data repository.
Note that when restoring a workspace, any existing symbol or file with same name
will be overridden.

# Arguments
- `conns::Union{DSConnection, Vector{<:DSConnection}}`: Connection object or a vector of connection objects
- `ws::String`: The workspace name
"""
function datashield_workspace_restore(
    conns::Union{DSConnection,Vector{<:DSConnection}}, ws::String
)
    datashield_sessions(conns)
    if conns isa Vector{<:DSConnection}
        for conn in conns
            datashield_workspace_restore(conn, ws)
        end
    else
        name = "$(conns.name):$(ws)"
        dsRestoreWorkspace(conns, name)
    end
    return nothing
end

"""
    datashield_workspace_rm(conns, ws)

Remove in each data repository the workspace with the provided name.

# Arguments
- `conns::Union{DSConnection, Vector{<:DSConnection}}`: Connection object or a vector of connection objects
- `ws::String`: The workspace name
"""
function datashield_workspace_rm(
    conns::Union{DSConnection,Vector{<:DSConnection}}, ws::String
)
    if conns isa Vector{<:DSConnection}
        for conn in conns
            datashield_workspace_rm(conn, ws)
        end
    else
        name = "$(conns.name):$(ws)"
        dsRmWorkspace(conns, name)
    end
    return nothing
end
