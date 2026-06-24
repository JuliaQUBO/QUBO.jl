using Test

include(joinpath(@__DIR__, "..", "scripts", "ecosystem_canary.jl"))

function test_ecosystem_canary()
    @testset "Ecosystem Canary" begin
        tier, allow_import_failure, packages = parse_args([
            "--tier",
            "tier-2",
            "--allow-import-failure",
            "DWave",
            "QUBOTools",
            "QUBO",
        ])

        @test tier == "tier-2"
        @test allow_import_failure == Set(["DWave"])
        @test packages == ["QUBOTools", "QUBO"]
        @test CORE_PACKAGE_NAMES == ["QUBOTools", "ToQUBO", "QUBODrivers"]

        latest_versions = Dict(
            "QUBOTools" => v"0.14.4",
            "ToQUBO" => v"0.5.0",
            "QUBODrivers" => v"0.6.3",
        )
        fresh_manifest = copy(latest_versions)
        stale_manifest = merge(fresh_manifest, Dict("QUBOTools" => v"0.13.3"))

        fresh_results = core_version_results(CORE_PACKAGE_NAMES, latest_versions, fresh_manifest)
        @test all(result -> result.ok, fresh_results)

        stale_results = core_version_results(CORE_PACKAGE_NAMES, latest_versions, stale_manifest)
        @test !all(result -> result.ok, stale_results)
        @test only(result for result in stale_results if result.package == "QUBOTools").resolved == v"0.13.3"
        @test version_label(nothing) == "missing"

        root = joinpath(@__DIR__, "..")
        workflow = read(joinpath(root, ".github", "workflows", "ecosystem-canary.yml"), String)
        script = read(joinpath(root, "scripts", "ecosystem_canary.jl"), String)

        for package in CORE_PACKAGE_NAMES
            @test occursin(package, workflow)
        end
        @test occursin("Pkg.add(packages)", script)
        @test !occursin("Pkg.develop", script)
    end

    return nothing
end
