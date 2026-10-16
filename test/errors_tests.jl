# Unit tests for the error tracking and message formatting

using DatashieldInterface
using Test

@testset "Append Error" begin
    DatashieldInterface._clear_last_errors()
    DatashieldInterface._append_error("server1", "something went wrong")
    @test DatashieldInterface._has_last_errors("server1")
    @test !DatashieldInterface._has_last_errors("server2")

    # messages are appended
    DatashieldInterface._append_error("server1", "still wrong")
    errs = datashield_errors()
    @test errs["server1"] == ["something went wrong", "still wrong"]

    DatashieldInterface._clear_last_errors()
    @test isnothing(datashield_errors())
end

@testset "Error Messages" begin
    DatashieldInterface._clear_last_errors()
    DatashieldInterface._append_error("server1", "error {with} brackets")
    msgs = datashield_error_messages()
    @test length(msgs) == 1
    @test occursin("server1", msgs[1])
    @test occursin("(with) brackets", msgs[1])
    DatashieldInterface._clear_last_errors()
end

@testset "Handle Errors" begin
    DatashieldInterface._clear_last_errors()
    # no errors: nothing is raised
    @test_nowarn DatashieldInterface._handle_errors(false)

    # errors with errors_print = false: a warning is issued
    DatashieldInterface._append_error("server1", "something went wrong")
    @test_logs (:warn,) begin
        @test_nowarn DatashieldInterface._handle_errors(false)
    end

    # errors with errors_print = true: an error is raised
    @test_throws ErrorException DatashieldInterface._handle_errors(true)
    DatashieldInterface._clear_last_errors()
end

@testset "Get Sleep Time Errors" begin
    @test isnothing(DatashieldInterface._clear_cache())
end
