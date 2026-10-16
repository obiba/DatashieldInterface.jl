# Unit tests for the DSLoginBuilder

using DatashieldInterface
using Test
using DataFrames

@testset "LoginBuilder Creation" begin
    builder = newDSLoginBuilder()
    @test isa(builder, DSLoginBuilder)
    @test size(build(builder), 1) == 0
end

@testset "LoginBuilder Append" begin
    builder = newDSLoginBuilder()
    append!(
        builder;
        server="server1",
        url="https://opal-demo.obiba.org",
        table="CNSIM.CNSIM1",
        user="dsuser",
        password="password",
    )
    logindata = build(builder)
    @test isa(logindata, DataFrame)
    @test size(logindata, 1) == 1
    @test logindata[1, "server"] == "server1"
    @test logindata[1, "table"] == "CNSIM.CNSIM1"
    @test logindata[1, "driver"] == "OpalDriver"

    # append a second server
    append!(
        builder;
        server="server2",
        url="https://opal-test.obiba.org",
        resource="RSRC.CNSIM1",
        token="123456789",
    )
    logindata = build(builder)
    @test size(logindata, 1) == 2
    @test logindata[2, "resource"] == "RSRC.CNSIM1"
    @test logindata[2, "user"] == ""
end

@testset "LoginBuilder Errors" begin
    builder = newDSLoginBuilder()
    @test_throws ErrorException append!(
        builder; server="", url="https://opal-demo.obiba.org"
    )
    @test_throws ErrorException append!(builder; server="server1", url="")

    # duplicate server names are not allowed
    append!(
        builder; server="server1", url="https://opal-demo.obiba.org", table="CNSIM.CNSIM1"
    )
    @test_throws ErrorException append!(
        builder; server="server1", url="https://opal-test.obiba.org"
    )
end

@testset "LoginBuilder Init With Data Frame" begin
    logindata = DataFrame(
        "server" => ["server1", "server2"],
        "url" => ["https://opal-demo.obiba.org", "https://opal-test.obiba.org"],
        "table" => ["CNSIM.CNSIM1", ""],
        "resource" => ["", "RSRC.CNSIM1"],
        "driver" => ["OpalDriver", "OpalDriver"],
        "user" => ["dsuser", ""],
        "password" => ["password", ""],
        "token" => ["", "123456789"],
        "profile" => ["", ""],
        "options" => ["", ""],
    )
    builder = newDSLoginBuilder(; logins=logindata)
    built = build(builder)
    @test size(built, 1) == 2
    @test names(built) == DatashieldInterface.LOGIN_COLUMNS

    # columns that are not provided are filled with empty strings
    minimal = DataFrame(
        "server" => ["server1"],
        "url" => ["https://opal-demo.obiba.org"],
        "table" => ["CNSIM.CNSIM1"],
    )
    built = build(newDSLoginBuilder(; logins=minimal))
    @test built[1, "resource"] == ""
    @test built[1, "driver"] == ""

    # a data frame without table nor resource columns is not valid
    nologins = DataFrame("dummy" => ["x"])
    @test_throws ErrorException newDSLoginBuilder(; logins=nologins)
end

@testset "LoginBuilder Silent Warning" begin
    # non secure http urls are warned, unless the builder is silent
    @test_logs (:warn,) begin
        append!(
            newDSLoginBuilder();
            server="server1",
            url="http://molgenis.example.org",
            table="CNSIM.CNSIM1",
        )
    end
    builder = newDSLoginBuilder(; silent=true)
    @test_nowarn append!(
        builder; server="server1", url="http://molgenis.example.org", table="CNSIM.CNSIM1"
    )
    @test size(build(builder), 1) == 1
end
