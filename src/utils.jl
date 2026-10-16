using DataFrames

# Analytic environment state, translated from R's per-environment variables
# (.datashield.last_errors, .datashield.pkg_status, default.connections)
const _STATE = Dict{String,Any}()
const _LAST_ERRORS_KEY = ".datashield.last_errors"
const _PKG_STATUS_KEY = ".datashield.pkg_status"
const _DEFAULT_CONNECTIONS_KEY = "default.connections"
const _INFORMED = Set{String}()
const _DRIVERS = Dict{String,Function}()

"""
    _newProgress(total; format="  :what [:bar] :percent /:elapsed", width=100) -> _Progress

Create a new progress instance with default settings.
"""
mutable struct _Progress
    total::Int
    count::Int
    format::String
    width::Int
end

function _newProgress(total::Int; format="  :what [:bar] :percent /:elapsed", width=100)
    pb = _Progress(total, 0, format, width)
    return pb
end

"""
    _tickProgress(pb; what="")

Update and increment the progress status.
"""
function _tickProgress(pb::Union{_Progress,Nothing}; what="")
    if isnothing(pb)
        return nothing
    end
    pb.count += 1
    if !isempty(what)
        println(what)
    else
        percent = pb.total > 0 ? round(Int, 100 * pb.count / pb.total) : 100
        println(percent, "%")
    end
    return nothing
end

"""
    _updateProgress(pb; step, total, what="")

Update the progress status.
"""
function _updateProgress(pb::Union{_Progress,Nothing}; step::Real, total::Real, what="")
    if isnothing(pb)
        return nothing
    end
    ratio = total > 0 ? step / total : 1.0
    pb.count = round(Int, ratio * pb.total)
    if !isempty(what)
        println(what)
    end
    return nothing
end

"""
Deparse language expression.
"""
function _deparse(expr)
    return expr isa Expr ? string(expr) : expr
end

"""
Makes a single connection or a named dictionary of connections.
"""
function _as_named_list_of_connections(conns::Union{DSConnection,Vector{<:DSConnection}})
    if conns isa DSConnection
        return Dict{String,DSConnection}(conns.name => conns)
    end
    return Dict{String,DSConnection}(c.name => c for c in conns)
end

"""
Makes a connection name. A single connection object or a named list of
connection objects.
"""
function _as_connections(conns::Union{DSConnection,Vector{<:DSConnection}})
    return conns isa DSConnection ? [conns] : conns
end

"""
Makes a typical logindata data frame a dictionary of tables named by the server
in which they are defined. Makes a string or a vector of table names a
dictionary named by the connections.
"""
function _as_named_list_of_values(
    conns::Union{DSConnection,Vector{<:DSConnection}}, value; colname=nothing
)
    cs = _as_named_list_of_connections(conns)
    if value isa DataFrame &&
        !isnothing(colname) &&
        hasproperty(value, Symbol(colname)) &&
        hasproperty(value, :server)
        return Dict{String,Any}(
            string(row[:server]) => row[Symbol(colname)] for row in eachrow(value)
        )
    elseif value isa AbstractDict
        return Dict{String,Any}(string(k) => v for (k, v) in value)
    elseif value isa AbstractString
        return Dict{String,Any}(name => value for (name, _) in pairs(cs))
    elseif value isa AbstractVector
        cnames = [name for (name, _) in pairs(cs)]
        return Dict{String,Any}(cnames[i] => value[i] for i in eachindex(cnames))
    elseif value isa Expr
        return Dict{String,Any}(name => value for (name, _) in pairs(cs))
    else
        return value
    end
end

"""
Filter the named dictionary of connections by connection names.
"""
function _filter_connections_by_name(conns::AbstractDict, names::AbstractVector)
    fconns = Dict{String,DSConnection}()
    for n in names
        if haskey(conns, n)
            fconns[n] = conns[n]
        end
    end
    return fconns
end

"""
Check that the provided object is a connection.
"""
function _is_ds_connection(obj)
    return obj isa DSConnection
end

"""
Clear some cache.
"""
function _clear_cache()
    delete!(_STATE, _PKG_STATUS_KEY)
    return nothing
end

"""
Clear last errors.
"""
function _clear_last_errors()
    delete!(_STATE, _LAST_ERRORS_KEY)
    return nothing
end

"""
Check if there are last errors.
"""
function _has_last_errors(name::String)
    if haskey(_STATE, _LAST_ERRORS_KEY)
        errs = _STATE[_LAST_ERRORS_KEY]
        return haskey(errs, name)
    else
        return false
    end
end

"""
Check if there are last errors and, if so, throw an error or issue a warning.
"""
function _check_last_errors()
    if haskey(_STATE, _LAST_ERRORS_KEY)
        @warn "There are some DataSHIELD errors, list them with datashield_errors()"
    end
    return nothing
end

"""
Append error message to last errors dictionary.
"""
function _append_error(name::String, msg::String)
    if haskey(_STATE, _LAST_ERRORS_KEY)
        errs = _STATE[_LAST_ERRORS_KEY]
        if haskey(errs, name)
            push!(errs[name], msg)
        else
            errs[name] = String[msg]
        end
        _STATE[_LAST_ERRORS_KEY] = errs
    else
        errs = Dict{String,Vector{String}}()
        errs[name] = String[msg]
        _STATE[_LAST_ERRORS_KEY] = errs
    end
    return nothing
end

"""
Check if a callback parameter is a valid function.
"""
function _is_callback(cb)
    return !isnothing(cb) && cb isa Function
end

"""
Get time to sleep depending on the number of previous iterations.
"""
function _get_sleep_time(checks::Integer)
    t0 = 0.05
    t1 = 1
    # wait 2s after 10s
    t10 = t1 * 2
    # wait 10s after 1min
    t60 = t1 * 10
    # wait 1min after 10mins
    t600 = t1 * 60
    # wait 10min after 1h
    t3600 = t1 * 600
    n1 = 1 / t0
    n10 = n1 + 9 / t1
    n60 = n10 + 50 / t10
    n600 = n60 + 540 / t60
    n3600 = n600 + 3000 / t600
    t = t0
    if checks >= n1 && checks < n10
        t = t1
    elseif checks >= n10 && checks < n60
        t = t10
    elseif checks >= n60 && checks < n600
        t = t60
    elseif checks >= n600 && checks < n3600
        t = t600
    elseif checks >= n3600
        t = t3600
    end
    return t
end

"""
Get the message of an exception.
"""
function _condition_message(e)
    if e isa ErrorException
        return e.msg
    else
        return sprint(showerror, e)
    end
end

"""
Create message informing of new functionality. This message informs the user about
the updated behavior regarding the automatic printing of DataSHIELD errors.
"""
function _new_errors_message()
    return ["Errors can now be automatically printed, rather than requiring a call to
    datashield_errors()."]
end

"""
Display informational messages once per session. An internal set is used to track
which messages have been shown.
"""
function _inform_once(msg, id=msg)
    if id in _INFORMED
        return nothing
    end
    push!(_INFORMED, string(id))
    for m in msg
        println(m)
    end
    println("This message is displayed once per session.")
    return nothing
end

"""
Handle DataSHIELD errors based on the errors.print flag. If errors.print is true,
an error is raised when there are last errors. If errors.print is false, a check of
the last errors is triggered.
"""
function _handle_errors(errors_print::Bool)
    if errors_print
        if haskey(_STATE, _LAST_ERRORS_KEY)
            returned_errors = _format_errors(_STATE[_LAST_ERRORS_KEY])
            msg = join(returned_errors, " ")
            throw(ErrorException("There are some DataSHIELD errors: $msg"))
        end
    else
        _check_last_errors()
    end
    return nothing
end

"""
Format errors into a vector of strings with each error message prefixed by a cross.
"""
function _format_errors(errors)
    no_brackets = _remove_curly_brackets(errors)
    msgs = String[]
    for (name, values) in no_brackets
        for value in values
            push!(msgs, "$name: $value")
        end
    end
    return msgs
end

"""
Replace all curly brackets in the input strings with parentheses.
"""
function _remove_curly_brackets(errors)
    if isnothing(errors)
        return nothing
    end
    rval = Dict{String,Vector{String}}()
    for (name, values) in errors
        rval[name] = [replace(replace(v, "{" => "("), "}" => ")") for v in values]
    end
    return rval
end

"""
Format cohort names with ANSI escape codes to make the text bold and yellow.
"""
function _format_cohort_colour(errors)
    cohorts = collect(keys(errors))
    return ["\033[1m\033[33m$cohort\033[39m: " for cohort in cohorts]
end

"""
Register a driver constructor with the provided name. The driver constructor is a
zero-argument function that builds a driver (the `dsConnect` implementations dispatch
on the driver type).
"""
function register_driver!(name::AbstractString, factory::Function)
    _DRIVERS[string(name)] = factory
    return nothing
end

"""
Get the registered driver constructor with the provided name.
"""
function get_driver(name::AbstractString)
    if haskey(_DRIVERS, string(name))
        return _DRIVERS[string(name)]
    end
    throw(
        ArgumentError(
            "Driver \"$name\" is not registered. Use register_driver! to register a driver constructor.",
        ),
    )
end
