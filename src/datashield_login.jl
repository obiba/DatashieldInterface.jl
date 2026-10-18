using DataFrames: DataFrame, eachrow

"""
    datashield_login(logins; assign=false, variables=nothing, missings=false, symbol="D", id_name=nothing, opts=Dict(), restore=nothing, fail_safe=false)

Logs in DataSHIELD R sessions and optionally assigns variables to R. This function
allows for clients to login to data repository servers and (optionally) assign all
the data or specific variables from the data repositories tables to data frames.
The assigned data frames (one for each data repository) are named 'D' (by default).

Different login strategies are supported: using a certificate/private key pair
(2-way SSL encryption mechanism), using user credentials (user name and password)
or using a personal access token.

# Arguments
- `logins::DataFrame`: A data frame that holds login details. The expected column names are
  'driver' (the `DSDriver` name, default is "OpalDriver"), 'server' (the server name),
  'url' (the server url), 'user' (the user name or the certificate PEM file path),
  'password' (the user password or the private key PEM file path), 'token' (the personal access
  token, ignored if 'user' is defined), 'table' (the fully qualified name of the table in the
  data repository), 'resource' (the fully qualified name of the resource reference in the data
  repository), 'profile' (an optional DataSHIELD profile name), 'options' (the SSL options)
- `assign::Bool=false`: A boolean which tells whether or not data should be assigned from the
  data repository table to R after login into the server(s)
- `variables=nothing`: Specific variables to assign. If `assign` is false this argument is
  ignored otherwise the specified variables are assigned; if no variables are specified the
  whole data repository's table is assigned
- `missings::Bool=false`: If true, missing values will be pushed from data repository to R
- `symbol::String="D"`: The name of the data frame to which the data repository's table will
  be assigned after login into the server(s)
- `id_name::Union{Nothing, String}=nothing`: Name of the column that will contain the entity
  identifiers
- `opts::Dict=Dict()`: Default SSL options to be used in case it is not specified in the
  logins structure
- `restore::Union{Nothing, String}=nothing`: The workspace name to restore
- `fail_safe::Bool=false`: Ignores, with a warning, the servers for which the connection cannot
  be established

# Returns
- A vector of connection objects
"""
function datashield_login(
    logins;
    assign::Bool=false,
    variables=nothing,
    missings::Bool=false,
    symbol::String="D",
    id_name=nothing,
    opts::Dict=Dict{String,Any}(),
    restore::Union{Nothing,String}=nothing,
    fail_safe::Bool=false,
)
    _clear_last_errors()
    defaultDriver = "OpalDriver"

    if isnothing(logins) || size(logins, 1) == 0
        throw(ErrorException("Provide valid login details!"))
    end

    # studies names
    stdnames = [string(x) for x in logins.server]
    # URLs
    urls = [string(x) for x in logins.url]
    # usernames
    userids = if hasproperty(logins, :user)
        _string_column(logins.user)
    else
        fill("", length(stdnames))
    end
    # passwords
    pwds = if hasproperty(logins, :password)
        _string_column(logins.password)
    else
        fill("", length(stdnames))
    end
    # tokens
    tokens = if hasproperty(logins, :token)
        _string_column(logins.token)
    else
        fill("", length(stdnames))
    end
    # profiles
    profiles = if hasproperty(logins, :profile)
        _string_column(logins.profile)
    else
        fill("", length(stdnames))
    end
    # table fully qualified names
    tables = if hasproperty(logins, :table)
        _string_column(logins.table)
    else
        fill("", length(stdnames))
    end
    # resource fully qualified names
    resources = if hasproperty(logins, :resource)
        _string_column(logins.resource)
    else
        fill("", length(stdnames))
    end
    # identifiers mapping
    idmappings = if hasproperty(logins, :identifiers)
        _string_column(logins.identifiers)
    else
        fill("", length(stdnames))
    end
    # connection specific options
    options = if hasproperty(logins, :options)
        _string_column(logins.options)
    else
        fill("", length(stdnames))
    end
    # driver name for instanciation
    drivers = if hasproperty(logins, :driver)
        _string_column(logins.driver, defaultDriver)
    else
        fill(defaultDriver, length(stdnames))
    end

    # login to the connections keeping the server names as specified in the login file
    println("Logging into the collaborating servers")
    connections = Vector{Union{Nothing,DSConnection}}(nothing, length(stdnames))
    pb = _newProgress(1 + length(connections))

    function doConnection(i)
        # connection options
        conn_opts = copy(opts)
        # instanciate the driver
        drv = get_driver(drivers[i])()
        # if the connection is HTTPS use ssl options else they are not required
        protocol = split(urls[i], "://")[1]
        profile = isempty(profiles[i]) ? nothing : profiles[i]
        if protocol == "https"
            # pem files or username/password or token ?
            if endswith(userids[i], ".pem")
                cert = userids[i]
                private = pwds[i]
                merge!(conn_opts, Dict("sslcert" => cert, "sslkey" => private))
                return dsConnect(
                    drv, stdnames[i]; url=urls[i], opts=conn_opts, profile=profile
                )
            else
                return dsConnect(
                    drv,
                    stdnames[i];
                    username=userids[i],
                    password=pwds[i],
                    token=tokens[i],
                    url=urls[i],
                    profile=profile,
                    opts=conn_opts,
                )
            end
        else
            return dsConnect(
                drv,
                stdnames[i];
                username=userids[i],
                password=pwds[i],
                token=tokens[i],
                url=urls[i],
                profile=profile,
                opts=conn_opts,
            )
        end
    end

    for i in eachindex(connections)
        _tickProgress(pb; what="Login $(stdnames[i])")
        if fail_safe
            try
                connections[i] = doConnection(i)
            catch e
                @warn "$(stdnames[i]) is excluded because login connection failed"
                connections[i] = nothing
            end
        else
            connections[i] = doConnection(i)
        end
    end
    _tickProgress(pb; what="Logged in all servers")

    # sanity check: server availability and table path is valid
    excluded = Bool[]
    for i in eachindex(connections)
        if !isempty(tables[i])
            res = try
                dsHasTable(connections[i], tables[i])
            catch
                nothing
            end
            push!(excluded, (res isa Bool && !res) || !isa(res, Bool))
            if (res isa Bool && !res) || !isa(res, Bool)
                @warn "$(stdnames[i]) will be excluded because table $(tables[i]) is not accessible"
            end
        elseif !isempty(resources[i])
            res = try
                dsHasResource(connections[i], resources[i])
            catch
                nothing
            end
            push!(excluded, (res isa Bool && !res) || !isa(res, Bool))
            if (res isa Bool && !res) || !isa(res, Bool)
                @warn "$(stdnames[i]) will be excluded because resource $(resources[i]) is not accessible"
            end
        else
            push!(excluded, false)
        end
    end

    rconnections = DSConnection[]
    for i in eachindex(connections)
        if !excluded[i] && !isnothing(connections[i])
            push!(rconnections, connections[i])
        end
    end

    # if restore is not nothing, restore the workspaces
    if !isnothing(restore) && !isempty(rconnections)
        datashield_workspace_restore(rconnections, restore)
    end

    # if argument 'assign' is true assign data/resources to the data repository server(s)
    # you logged in to
    if assign && !isempty(rconnections)
        isNotEmpty = x -> !(x isa AbstractString && isempty(x))
        if all(isNotEmpty, resources)
            try
                datashield_assign_resource(rconnections, symbol, logins)
            catch
                @warn "Resource assignment failed"
            end
        end
        if all(isNotEmpty, tables)
            try
                datashield_assign_table(
                    rconnections,
                    symbol,
                    logins;
                    variables=variables,
                    missings=missings,
                    id_name=id_name,
                )
            catch
                @warn "Table assignment failed"
            end
        end
    end

    _clear_cache()

    # return the connection objects
    return rconnections
end

"""
Get the values of a login data frame column as a vector of strings, mapping missing
and empty values to the provided default.
"""
function _string_column(column, default="")
    return [
        (ismissing(x) || isnothing(x) || isempty(string(x))) ? default : string(x) for
        x in column
    ]
end

"""
Get the profile or nothing if empty.
"""
function _profile_or_nothing(profile::AbstractString)
    return isempty(profile) ? nothing : profile
end
