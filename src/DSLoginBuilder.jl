const LOGIN_COLUMNS = [
    "server",
    "url",
    "table",
    "resource",
    "driver",
    "user",
    "password",
    "token",
    "profile",
    "options",
]

"""
    DSLoginBuilder

Helper class for creating a valid data frame that can be used to perform
`datashield_login`. See also `newDSLoginBuilder`.
"""
mutable struct DSLoginBuilder
    logins::Union{Nothing,DataFrame}
    silent::Bool
end

"""
    newDSLoginBuilder(; logins=nothing, silent=false) -> DSLoginBuilder

Shortcut function to create a new `DSLoginBuilder` instance. The data frame that
is being built can be used to perform `datashield_login`.

# Arguments
- `logins::Union{DataFrame, Nothing}=nothing`: A valid login details data frame to initiate the builder
- `silent::Bool=false`: Do not warn user when non secure HTTP urls are encountered
"""
function newDSLoginBuilder(; logins::Union{Nothing,DataFrame}=nothing, silent::Bool=false)
    return DSLoginBuilder(_as_logins(logins), silent)
end

"""
    append!(builder::DSLoginBuilder; server, url, table="", resource="", driver="OpalDriver", user="", password="", token="", options="", profile="")

Append login information for a specific server.

# Arguments
- `builder::DSLoginBuilder`: The DataSHIELD login details builder
- `server::AbstractString`: The server name (must be unique)
- `url::AbstractString`: The url to connect to the server or a symbol name
- `table::AbstractString=""`: The table path that identifies the dataset in the server
- `resource::AbstractString=""`: The resource path that identifies the resource reference in the server
- `driver::AbstractString="OpalDriver"`: The `DSDriver` name to build the `DSConnection`
- `user::AbstractString=""`: The user name in the user credentials
- `password::AbstractString=""`: The user password in the user credentials
- `token::AbstractString=""`: The personal access token (ignored when user credentials are not empty)
- `options::AbstractString=""`: Any options that could be relevant for the DS connection object
- `profile::AbstractString=""`: The DataSHIELD R server profile
"""
function Base.append!(
    builder::DSLoginBuilder;
    server,
    url,
    table="",
    resource="",
    driver="OpalDriver",
    user="",
    password="",
    token="",
    options="",
    profile="",
)
    if _isempty_login(server)
        throw(ErrorException("The server parameter cannot be empty"))
    end
    if _isempty_login(url)
        throw(ErrorException("The url parameter cannot be empty"))
    elseif startswith(url, "http") && !startswith(url, "https") && !builder.silent
        @warn "Secure HTTP connection is recommended: $url"
    end

    lg = _get_logins(builder)
    if size(lg, 2) == 0
        builder.logins = DataFrame(
            "server" => [server],
            "url" => [url],
            "table" => [table],
            "resource" => [resource],
            "driver" => [driver],
            "user" => [user],
            "password" => [password],
            "token" => [token],
            "profile" => [profile],
            "options" => [options],
        )
    else
        if server in lg.server
            throw(ErrorException("Duplicate server name: $server"))
        end
        push!(
            lg,
            (
                server=string(server),
                url=string(url),
                table=string(table),
                resource=string(resource),
                driver=string(driver),
                user=string(user),
                password=string(password),
                token=string(token),
                profile=string(profile),
                options=string(options),
            );
            promote=true,
        )
    end
    return nothing
end

"""
    build(builder::DSLoginBuilder) -> DataFrame

Build the DSLoginBuilder instance.

# Returns
- The DataSHIELD logindata data frame
"""
function build(builder::DSLoginBuilder)
    return _get_logins(builder)
end

"""
Validate the provided login details data frame: required columns are server, url
and at least one of table or resource.
"""
function _as_logins(df::Union{Nothing,DataFrame})
    if isnothing(df)
        return nothing
    end
    cnames = names(df)
    if !("server" in cnames)
        throw(ErrorException("The provided login details is missing server column"))
    end
    if !("url" in cnames)
        throw(ErrorException("The provided login details is missing url column"))
    end
    if !("table" in cnames) && !("resource" in cnames)
        throw(
            ErrorException(
                "The provided login details is missing both table and resource columns"
            ),
        )
    end
    nrow = size(df, 1)
    columns = Dict{String,AbstractVector}()
    for colname in LOGIN_COLUMNS
        if colname in cnames
            columns[colname] = string.(df[!, colname])
        else
            columns[colname] = fill("", nrow)
        end
    end
    return DataFrame([colname => columns[colname] for colname in LOGIN_COLUMNS]...)
end

"""
Get the login details data frame, an empty one if not yet initialized.
"""
function _get_logins(builder::DSLoginBuilder)
    if isnothing(builder.logins)
        builder.logins = DataFrame([colname => String[] for colname in LOGIN_COLUMNS]...)
    end
    return builder.logins
end

"""
Check if a login detail value is empty.
"""
function _isempty_login(value)
    return isnothing(value) ||
           ismissing(value) ||
           (value isa AbstractString && isempty(value))
end
