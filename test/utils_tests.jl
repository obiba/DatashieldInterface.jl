# Unit tests for the internal utilities and helpers

using DatashieldInterface
using Test

@testset "Filter Connections By Name" begin
    conn1 = mock_connection("server1")
    conn2 = mock_connection("server2")
    conns = Dict("server1" => conn1, "server2" => conn2)
    fconns = DatashieldInterface._filter_connections_by_name(conns, ["server1"])
    @test haskey(fconns, "server1")
    @test !(haskey(fconns, "server2"))
end

@testset "Named List Of Values" begin
    conn = mock_connection("server1")
    conns = [conn]

    # name lookups go through the connection name
    tables = DatashieldInterface._as_named_list_of_values(
        conns,
        DataFrame("server" => ["server1"], "table" => ["CNSIM.CNSIM1"]);
        colname="table",
    )
    @test tables["server1"] == "CNSIM.CNSIM1"

    # a single name is applied to each connection
    tables = DatashieldInterface._as_named_list_of_values(
        conns, "CNSIM.CNSIM1"; colname="table"
    )
    @test tables["server1"] == "CNSIM.CNSIM1"

    # expressions are applied to each connection
    exprs = DatashieldInterface._as_named_list_of_values(conns, :(meanDS(D, 123)))
    @test exprs["server1"] == :(meanDS(D, 123))

    # dictionaries are keyed by connection name
    exprs = DatashieldInterface._as_named_list_of_values(
        conns, Dict("server1" => :(meanDS(D, 123)))
    )
    @test exprs["server1"] == :(meanDS(D, 123))
end

@testset "Sleep Time" begin
    @test DatashieldInterface._get_sleep_time(1) == 0.05
    @test DatashieldInterface._get_sleep_time(20) == 1
    @test DatashieldInterface._get_sleep_time(30) == 2
    @test DatashieldInterface._get_sleep_time(100000) == 600
end

@testset "Driver Registry" begin
    register_mock_driver()
    @test isa(get_driver("MockDriver")(), MockDriver)
    @test_throws ArgumentError get_driver("UnknownDriver")
end
