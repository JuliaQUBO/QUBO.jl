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
        @test CORE_PACKAGE_NAMES == [
            "PseudoBooleanOptimization",
            "QUBOTools",
            "ToQUBO",
            "QUBODrivers",
        ]

        latest_versions = Dict(
            "PseudoBooleanOptimization" => v"0.2.6",
            "QUBOTools" => v"0.15.0",
            "ToQUBO" => v"0.5.0",
            "QUBODrivers" => v"0.6.3",
        )
        fresh_manifest = copy(latest_versions)
        stale_manifest = merge(fresh_manifest, Dict("QUBOTools" => v"0.14.4"))
        stale_pbo_manifest = merge(fresh_manifest, Dict("PseudoBooleanOptimization" => v"0.2.5"))

        fresh_results = core_version_results(CORE_PACKAGE_NAMES, latest_versions, fresh_manifest)
        @test all(result -> result.ok, fresh_results)

        stale_results = core_version_results(CORE_PACKAGE_NAMES, latest_versions, stale_manifest)
        @test !all(result -> result.ok, stale_results)
        @test only(result for result in stale_results if result.package == "QUBOTools").resolved == v"0.14.4"
        stale_pbo_results = core_version_results(CORE_PACKAGE_NAMES, latest_versions, stale_pbo_manifest)
        @test !all(result -> result.ok, stale_pbo_results)
        @test only(result for result in stale_pbo_results if result.package == "PseudoBooleanOptimization").resolved ==
            v"0.2.5"
        @test version_label(nothing) == "missing"

        stable_version_info = Dict(
            v"1.0.0" => (; yanked = false),
            v"1.1.0" => (; yanked = true),
            v"1.2.0-beta" => (; yanked = false),
            v"1.3.0" => (; yanked = false),
        )
        stable_compatibility_info = Dict(
            v"1.0.0" => Dict(Pkg.Registry.JULIA_UUID => Pkg.Types.VersionSpec()),
            v"1.1.0" => Dict(Pkg.Registry.JULIA_UUID => Pkg.Types.VersionSpec()),
            v"1.2.0-beta" => Dict(Pkg.Registry.JULIA_UUID => Pkg.Types.VersionSpec()),
            v"1.3.0" => Dict(Pkg.Registry.JULIA_UUID => Pkg.Types.semver_spec("99")),
        )
        @test latest_installable_registered_version(
            "Example",
            stable_version_info,
            stable_compatibility_info,
        ) == v"1.0.0"
        @test_throws ErrorException latest_installable_registered_version(
            "Example",
            Dict(v"1.0.0" => (; yanked = true)),
            Dict(v"1.0.0" => Dict(Pkg.Registry.JULIA_UUID => Pkg.Types.VersionSpec())),
        )

        root = joinpath(@__DIR__, "..")
        workflow = read(joinpath(root, ".github", "workflows", "ecosystem-canary.yml"), String)
        maintenance = read(joinpath(root, "docs", "src", "maintenance.md"), String)
        script = read(joinpath(root, "scripts", "ecosystem_canary.jl"), String)

        for package in CORE_PACKAGE_NAMES
            @test occursin(package, workflow)
        end
        @test occursin("intentionally global", maintenance)
        @test occursin("Pkg.add(packages)", script)
        @test !occursin("Pkg.develop", script)
    end

    return nothing
end
