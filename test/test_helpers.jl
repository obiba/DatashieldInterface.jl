# Shared test helpers for DatashieldInterface.jl tests
# Provides a mock driver/connection implementing the DataSHIELD interface

using DatashieldInterface
using DataFrames
using Test

import DatashieldInterface:
    dsConnect,
    dsDisconnect,
    dsKeepAlive,
    dsIsAsync,
    dsHasSession,
    dsSession,
    dsIsReady,
    dsStateMessage,
    dsListTables,
    dsHasTable,
    dsListResources,
    dsHasResource,
    dsListSymbols,
    dsRmSymbol,
    dsListProfiles,
    dsListMethods,
    dsListPackages,
    dsListWorkspaces,
    dsSaveWorkspace,
    dsRestoreWorkspace,
    dsRmWorkspace,
    dsAssignTable,
    dsAssignResource,
    dsAssignExpr,
    dsAggregate,
    dsIsCompleted,
    dsFetch,
    dsGetInfo

struct MockDriver <: DSDriver end

mutable struct MockConnection <: DSConnection
    name::String
    symbols::Vector{String}
end

mock_connection(name::String) = MockConnection(name, ["D"])

struct MockSession <: DSSession
    conn::MockConnection
end

struct MockResult <: DSResult
    conn::MockConnection
    value::Any
end

function dsConnect(
    ::MockDriver,
    name;
    username=nothing,
    password=nothing,
    token=nothing,
    url="",
    opts=Dict(),
    profile=nothing,
)
    MockConnection(name, String[])
end

dsHasTable(::MockConnection, table) = true
dsHasResource(::MockConnection, resource) = true
dsHasSession(::MockConnection) = false
dsListTables(::MockConnection) = ["CNSIM.CNSIM1"]
dsListResources(::MockConnection) = ["RSRC.CNSIM1"]

function dsIsAsync(::MockConnection)
    Dict(
        "session" => true,
        "aggregate" => true,
        "assignTable" => true,
        "assignResource" => true,
        "assignExpr" => true,
    )
end

dsSession(conn::MockConnection; async::Bool=true) = MockSession(conn)
dsIsReady(::MockSession) = true
dsStateMessage(::MockSession) = "Session is ready"
dsKeepAlive(::MockConnection) = nothing

function dsListSymbols(conn::MockConnection)
    return conn.symbols
end

function dsRmSymbol(conn::MockConnection, symbol)
    filter!(!=(symbol), conn.symbols)
    return nothing
end

dsListProfiles(::MockConnection) = Dict("available" => ["default"], "current" => "default")

function dsListMethods(::MockConnection; type="aggregate")
    methodname = type == "aggregate" ? "meanDS" : "assignDS"
    return DataFrame(;
        name=[methodname],
        type=[type],
        class=["function"],
        value=["mock()"],
        package=["mockpkg"],
        version=["1.0.0"],
    )
end

dsListPackages(::MockConnection) = DataFrame()

function dsListWorkspaces(::MockConnection)
    DataFrame(;
        name=["ws1"],
        user=["dsuser"],
        context=["R"],
        lastAccessDate=["2026-01-01"],
        size=[100],
    )
end

dsSaveWorkspace(::MockConnection, name) = nothing
dsRestoreWorkspace(::MockConnection, name) = nothing
dsRmWorkspace(::MockConnection, name) = nothing
dsDisconnect(::MockConnection; save=nothing) = nothing

function dsAssignTable(
    conn::MockConnection,
    symbol,
    table;
    variables=nothing,
    missings=false,
    identifiers=nothing,
    id_name=nothing,
    async=true,
)
    push!(conn.symbols, symbol)
    return MockResult(conn, "table-assigned")
end

function dsAssignResource(conn::MockConnection, symbol, resource; async::Bool=true)
    push!(conn.symbols, symbol)
    return conn
end

function dsAssignExpr(conn::MockConnection, symbol, expr; async::Bool=true)
    push!(conn.symbols, symbol)
    return MockResult(conn, nothing)
end

function dsAggregate(conn::MockConnection, expr; async::Bool=true)
    MockResult(conn, "aggregate-result")
end
dsIsCompleted(::MockResult) = true
dsFetch(res::MockResult) = res.value
dsGetInfo(::MockResult) = Dict("status" => "COMPLETED")

function register_mock_driver()
    register_driver!("MockDriver", () -> MockDriver())
    return nothing
end
