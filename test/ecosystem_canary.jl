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
            "QUBODecomposition",
        ]

        latest_versions = Dict(
            "PseudoBooleanOptimization" => v"0.3.0",
            "QUBOTools" => v"0.16.2",
            "ToQUBO" => v"0.7.1",
            "QUBODrivers" => v"0.6.5",
            "QUBODecomposition" => v"0.1.1",
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
        stale_toqubo_manifest = merge(fresh_manifest, Dict("ToQUBO" => v"0.6.1"))
        stale_toqubo_results = core_version_results(CORE_PACKAGE_NAMES, latest_versions, stale_toqubo_manifest)
        @test !all(result -> result.ok, stale_toqubo_results)
        @test !only(result for result in stale_toqubo_results if result.package == "ToQUBO").ok
        for (package, stale_version) in [
            "QUBODrivers" => v"0.6.4",
            "QUBODecomposition" => v"0.1.0",
        ]
            results = core_version_results(
                CORE_PACKAGE_NAMES,
                latest_versions,
                merge(fresh_manifest, Dict(package => stale_version)),
            )
            @test !all(result -> result.ok, results)
            @test !only(result for result in results if result.package == package).ok
        end
        # Follow future registry releases rather than freezing the adoption version.
        newer_versions = merge(latest_versions, Dict("QUBODecomposition" => v"0.1.2"))
        @test !all(result -> result.ok, core_version_results(CORE_PACKAGE_NAMES, newer_versions, fresh_manifest))
        @test all(result -> result.ok, core_version_results(CORE_PACKAGE_NAMES, newer_versions, newer_versions))
        for package in CORE_PACKAGE_NAMES
            missing_manifest = copy(fresh_manifest)
            delete!(missing_manifest, package)
            missing_results = core_version_results(CORE_PACKAGE_NAMES, latest_versions, missing_manifest)
            @test !all(result -> result.ok, missing_results)
            @test only(result for result in missing_results if result.package == package).resolved === nothing
        end
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

        # Inspect each executable command, so a mention in another tier or a
        # diagnostic alone cannot satisfy mandatory resolution/import membership.
        commands = [split(match.captures[1]) for match in eachmatch(r"run: >\r?\n((?:          [^\r\n]*\r?\n)+)", workflow)]
        @test length(commands) == 4
        for tier in ("tier-1", "tier-2")
            command = only(command for command in commands if "--tier" in command && tier in command)
            @test command[1:2] == ["julia", "scripts/ecosystem_canary.jl"]
            parsed_tier, optional, package_names = parse_args(command[3:end])
            @test parsed_tier == tier
            @test all(package -> package in package_names, CORE_PACKAGE_NAMES)
            @test "QUBODecomposition" ∉ optional
            @test optional == (tier == "tier-1" ? Set{String}() : Set(["DWave", "PySA", "CIMOptimizer", "QiskitOpt"]))
            tier_commands = tier == "tier-1" ? commands[1:2] : commands[3:4]
            @test tier_commands[2] == command
            @test tier_commands[1][1:2] == ["julia", "scripts/compat_matrix.jl"]
            @test Set(tier_commands[1][3:end]) == Set(package_names)
        end
        @test occursin("intentionally global", maintenance)
        @test occursin("Pkg.add(packages)", script)
        @test !occursin("Pkg.develop", script)
    end

    return nothing
end
