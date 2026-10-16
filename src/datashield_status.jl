"""
    datashield_profiles(conns)

Get the list of all the DataSHIELD profiles from the different data repositories:
available ones and currently applied to each connection.

# Arguments
- `conns::Union{DSConnection, Vector{<:DSConnection}}`: Connection object or a vector of connection objects

# Returns
- Profiles details from all the servers
"""
function datashield_profiles(conns::Union{DSConnection,Vector{<:DSConnection}})
    onProfilesError =
        e -> begin
            @warn "Can't list profiles (is your DS driver library up to date?), using 'default' profile."
            return Dict("available" => "default", "current" => "default")
        end

    if conns isa Vector{<:DSConnection}
        profiles = Dict{String,Any}(conn.name => try
            dsListProfiles(conn)
        catch e
            onProfilesError(e)
        end for conn in conns)
    else
        profiles = Dict{String,Any}(conns.name => try
            dsListProfiles(conns)
        catch e
            onProfilesError(e)
        end)
    end

    allProfiles = String[]
    for std in keys(profiles)
        for p in get(profiles[std], "available", String[])
            p in allProfiles || push!(allProfiles, p)
        end
    end

    available = Dict{String,Dict{String,Bool}}()
    for std in keys(profiles)
        available[std] = Dict(
            p => p in get(profiles[std], "available", String[]) for p in allProfiles
        )
    end

    current = Dict{String,Any}(
        std => get(profiles[std], "current", nothing) for std in keys(profiles)
    )

    return Dict("available" => available, "current" => current)
end

"""
    datashield_methods(conns; type="aggregate")

Get the list of all the DataSHIELD methods from the different data repositories.

# Arguments
- `conns::Union{DSConnection, Vector{<:DSConnection}}`: Connection object or a vector of connection objects
- `type::String="aggregate"`: Type of the method: "aggregate" (default) or "assign"

# Returns
- Methods details from all the servers
"""
function datashield_methods(
    conns::Union{DSConnection,Vector{<:DSConnection}}; type::String="aggregate"
)
    if conns isa Vector{<:DSConnection}
        methods = Dict{String,Any}(
            conn.name => dsListMethods(conn; type=type) for conn in conns
        )
        ms = nothing
        for server in keys(methods)
            mdf = methods[server]
            mdf[!, "server"] = fill(server, size(mdf, 1))
            if isnothing(ms)
                ms = mdf
            else
                ms = vcat(ms, mdf)
            end
        end
        return isnothing(ms) ? DataFrame(; name=String[], type=String[]) : ms
    else
        return dsListMethods(conns; type=type)
    end
end

"""
    datashield_method_status(conns; type="aggregate")

Get the status of the DataSHIELD methods in the different data repositories to
check if any method is missing.

# Arguments
- `conns::Union{DSConnection, Vector{<:DSConnection}}`: Connection object or a vector of connection objects
- `type::String="aggregate"`: Type of the method: "aggregate" (default) or "assign"

# Returns
- Methods availability on each server
"""
function datashield_method_status(
    conns::Union{DSConnection,Vector{<:DSConnection}}; type::String="aggregate"
)
    cs = _as_named_list_of_connections(conns)

    methods = Dict{String,Any}(n => dsListMethods(c; type=type) for (n, c) in cs)

    # unique method names
    unique_name = String[]
    for x in values(methods)
        for n in x.name
            n in unique_name || push!(unique_name, n)
        end
    end

    server_names = sort(collect(keys(methods)))
    status = Dict{String,Any}()
    for server in server_names
        X = methods[server]
        status[server] = [n in X.name for n in unique_name]
    end

    if isempty(unique_name)
        return DataFrame()
    end
    columns = Pair{String,Any}[
        "name" => unique_name, "type" => fill(type, length(unique_name))
    ]
    for server in server_names
        push!(columns, server => status[server])
    end
    return DataFrame(columns)
end

"""
    datashield_pkg_status(conns)

Get the status of the DataSHIELD packages in the different data repositories to
check if any package is missing.

# Arguments
- `conns::Union{DSConnection, Vector{<:DSConnection}}`: Connection object or a vector of connection objects

# Returns
- Packages status for each server
"""
function datashield_pkg_status(conns::Union{DSConnection,Vector{<:DSConnection}})
    cs = _as_named_list_of_connections(conns)
    types = ["aggregate", "assign"]

    server_names = sort(collect(keys(cs)))
    pkgs = Dict{String,DataFrame}(n => DataFrame() for n in server_names)

    # get packages from methods info
    for type in types
        res = Dict(n => dsListMethods(cs[n]; type=type) for n in server_names)
        for n in server_names
            r = res[n]
            type_pkgs = if size(r, 1) > 0 && hasproperty(r, :package)
                unique(DataFrame(; package=r.package, version=r.version))
            else
                DataFrame(; package=String[], version=String[])
            end
            if size(pkgs[n], 1) == 0
                pkgs[n] = type_pkgs
            elseif size(type_pkgs, 1) > 0
                pkgs[n] = unique(vcat(pkgs[n], type_pkgs))
            end
        end
    end

    # package names
    unique_pkgs = String[]
    for x in values(pkgs)
        for p in x.package
            p in unique_pkgs || push!(unique_pkgs, string(p))
        end
    end

    # package status
    package_status = Dict{String,Any}()
    for n in server_names
        package_status[n] = [p in pkgs[n].package for p in unique_pkgs]
    end

    # package versions
    version_status = Dict{String,Any}()
    for n in server_names
        vstatus = Union{Missing,String}[]
        for y in unique_pkgs
            idx = findfirst(==(y), string.(pkgs[n].package))
            push!(vstatus, isnothing(idx) ? missing : pkgs[n].version[idx])
        end
        version_status[n] = vstatus
    end

    return Dict(
        "package_status" => package_status,
        "package_names" => unique_pkgs,
        "status_servers" => server_names,
        "version_status" => version_status,
    )
end

"""
    datashield_pkg_check(conns, name, version)

Check for each of the servers, accessible through provided connection objects,
whether the installed server-side package has at least the required version.

# Arguments
- `conns::Union{DSConnection, Vector{<:DSConnection}}`: Connection object or a vector of connection objects
- `name::String`: The name of the server-side package
- `version::String`: The minimum package version number to be matched
"""
function datashield_pkg_check(
    conns::Union{DSConnection,Vector{<:DSConnection}}, name::String, version::String
)
    status = nothing
    if haskey(_STATE, _PKG_STATUS_KEY)
        status = _STATE[_PKG_STATUS_KEY]
    end
    if isnothing(status)
        status = datashield_pkg_status(conns)
        _STATE[_PKG_STATUS_KEY] = status
    end

    unique_pkgs = status["package_names"]
    idx = findfirst(==(name), unique_pkgs)
    if isnothing(idx)
        throw(
            ErrorException(
                "Package $name is not installed on any of the servers. Minimum version required is $version",
            ),
        )
    end

    version_status = status["version_status"]
    for server in status["status_servers"]
        v = version_status[server][idx]
        if ismissing(v)
            throw(
                ErrorException(
                    "Package $name is not installed on server $server. Minimum version required is $version",
                ),
            )
        end
        if VersionNumber(string(v)) < VersionNumber(version)
            throw(
                ErrorException(
                    "Package $name on server $server has not the minimum version required: $v < $version",
                ),
            )
        end
    end
    return nothing
end

"""
    datashield_table_status(conns, table)

Get whether some identified tables are accessible in each of the data repositories.

# Arguments
- `conns::Union{DSConnection, Vector{<:DSConnection}}`: Connection object or a vector of connection objects
- `table`: Fully qualified name of a table in the data repository (can be a string, a vector of strings,
  a dictionary keyed by server name, or a data frame with 'server' and 'table' columns)

# Returns
- Table status for each server
"""
function datashield_table_status(conns::Union{DSConnection,Vector{<:DSConnection}}, table)
    # prepare tables as a named dictionary
    tables = _as_named_list_of_values(conns, table; colname="table")
    # make a named dictionary of connections
    cs = _as_named_list_of_connections(conns)

    server = collect(keys(cs))
    tbl = Union{Missing,String}[]
    accessible = Union{Missing,Bool}[]
    pb = _newProgress(1 + length(server))
    for n in server
        if haskey(tables, n)
            push!(tbl, string(tables[n]))
            push!(accessible, dsHasTable(cs[n], string(tables[n])))
        else
            push!(tbl, missing)
            push!(accessible, missing)
        end
        _tickProgress(pb; what="Checking $n")
    end
    _tickProgress(pb; what="All servers checked")
    return DataFrame(; server=server, table=tbl, accessible=accessible)
end

"""
    datashield_resource_status(conns, resource)

Get whether some identified resources are accessible in each of the data repositories.

# Arguments
- `conns::Union{DSConnection, Vector{<:DSConnection}}`: Connection object or a vector of connection objects
- `resource`: Fully qualified name of a resource in the data repository (can be a string, a vector of strings,
  a dictionary keyed by server name, or a data frame with 'server' and 'resource' columns)

# Returns
- Resource status for each server
"""
function datashield_resource_status(
    conns::Union{DSConnection,Vector{<:DSConnection}}, resource
)
    # prepare resources as a named dictionary
    resources = _as_named_list_of_values(conns, resource; colname="resource")
    # make a named dictionary of connections
    cs = _as_named_list_of_connections(conns)

    server = collect(keys(cs))
    res = Union{Missing,String}[]
    accessible = Union{Missing,Bool}[]
    pb = _newProgress(1 + length(server))
    for n in server
        if haskey(resources, n)
            push!(res, string(resources[n]))
            push!(accessible, dsHasResource(cs[n], string(resources[n])))
        else
            push!(res, missing)
            push!(accessible, missing)
        end
        _tickProgress(pb; what="Checking $n")
    end
    _tickProgress(pb; what="All servers checked")
    return DataFrame(; server=server, resource=res, accessible=accessible)
end
