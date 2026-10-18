# Unit tests for the client functions, with a mock driver implementing the
# DataSHIELD interface

using DatashieldInterface
using Test
using DataFrames

function make_logindata()
    return DataFrame(
        "server" => ["server1", "server2"],
        "url" => ["https://opal-demo.obiba.org", "https://opal-test.obiba.org"],
        "table" => ["CNSIM.CNSIM1", "CNSIM.CNSIM2"],
        "resource" => ["", ""],
        "driver" => ["MockDriver", "MockDriver"],
        "user" => ["dsuser", "dsuser"],
        "password" => ["password", "password"],
        "token" => ["", ""],
        "profile" => ["", ""],
        "options" => ["", ""],
    )
end

@testset "Login" begin
    register_mock_driver()
    conns = datashield_login(make_logindata())
    @test length(conns) == 2
    @test conns[1].name == "server1"
    @test conns[2].name == "server2"
end

@testset "Login Errors" begin
    register_mock_driver()
    # a driver that is not registered raises an error
    logindata = make_logindata()
    logindata[1, "driver"] = "UnknownDriver"
    @test_throws ArgumentError datashield_login(logindata)
    @test_throws ErrorException datashield_login(DataFrame())
end

@testset "Login Fail Safe" begin
    register_mock_driver()
    # a driver whose connection fails is excluded, with a warning
    register_driver!("FailingDriver", () -> throw(ErrorException("cannot connect")))
    logindata = make_logindata()
    logindata[1, "driver"] = "FailingDriver"
    @test_logs (:warn,) match_mode=:any begin
        conns = datashield_login(logindata; fail_safe=true)
        @test length(conns) == 1
        @test conns[1].name == "server2"
    end
    # without fail_safe the login fails
    @test_throws ErrorException datashield_login(logindata)
end

@testset "Logout" begin
    register_mock_driver()
    conns = datashield_login(make_logindata())
    @test_nowarn datashield_logout(conns)
end

@testset "Aggregate" begin
    register_mock_driver()
    conns = datashield_login(make_logindata())

    # single connection
    rval = datashield_aggregate(conns[1], "meanDS(D)")
    @test rval == "aggregate-result"

    # several connections, results are named by the connection name
    rval = datashield_aggregate(conns, "meanDS(D)")
    @test rval["server1"] == "aggregate-result"
    @test rval["server2"] == "aggregate-result"
end

@testset "Assign" begin
    register_mock_driver()
    conns = datashield_login(make_logindata())

    # table assignment
    datashield_assign_table(conns[1], "D", "CNSIM.CNSIM1")
    @test "D" in dsListSymbols(conns[1])

    # assignment on all the connections
    datashield_assign_expr(conns, "G", :(as.numeric(D.GENDER)))
    @test "G" in conns[1].symbols
    @test "G" in conns[2].symbols

    # symbols are listed and removed
    symbols = datashield_symbols(conns[1])
    @test "D" in symbols
    @test "G" in symbols
    datashield_rm(conns, "G")
    @test !("G" in conns[1].symbols)
end

@testset "Sessions" begin
    register_mock_driver()
    conns = datashield_login(make_logindata())
    # sessions are ensured to be up and running
    @test_nowarn datashield_sessions(conns)
end

@testset "Tables and Resources" begin
    register_mock_driver()
    conns = datashield_login(make_logindata())

    tables = datashield_tables(conns)
    @test tables["server1"] == DatashieldInterface.dsListTables(conns[1])
    @test haskey(tables, "server2")

    resources = datashield_resources(conns)
    @test haskey(resources, "server1")

    status = datashield_table_status(conns, "CNSIM.CNSIM1")
    @test status[1, "server"] == "server1"
    @test status[1, "table"] == "CNSIM.CNSIM1"
    @test status[1, "accessible"] == true

    wss = datashield_workspaces(conns)
    @test isa(wss, DataFrame)
    @test wss[1, "server"] == "server1"
    @test_nowarn datashield_workspace_save(conns, "testws")
    @test_nowarn datashield_workspace_rm(conns, "testws")
end

@testset "Profiles and Methods" begin
    register_mock_driver()
    conns = datashield_login(make_logindata())

    profiles = datashield_profiles(conns)
    @test profiles["available"]["server1"]["default"] == true
    @test profiles["current"]["server1"] == "default"

    methods = datashield_methods(conns)
    @test size(methods, 1) == 2
    @test "server" in names(methods)

    status = datashield_method_status(conns)
    @test isa(status, DataFrame)
    @test status[1, "name"] == "meanDS"

    pkg_status = datashield_pkg_status(conns)
    @test haskey(pkg_status, "package_status")
    @test haskey(pkg_status, "version_status")
end

@testset "Connections Registry" begin
    register_mock_driver()
    conns = datashield_login(make_logindata())

    # register the connections in Main
    Main.eval(:($(Symbol("test_conns")) = $conns))

    found = datashield_connections_find()
    @test found[1].name == "server1"

    @test_nowarn datashield_connections()

    # a single connection set is copied as the default set
    default = datashield_connections_default()
    @test !isnothing(default)
    @test default[1].name == "server1"

    datashield_connections_default(; name=Symbol("test_conns"))
    @test !isnothing(datashield_connections_default())
end
