using TOML
using Pkg

_compat_entries(value::AbstractString) = strip.(split(value, ','))

function test_package_metadata()
    @testset "Package Metadata" begin
        root = joinpath(@__DIR__, "..")
        project = TOML.parsefile(joinpath(root, "Project.toml"))
        compat = project["compat"]

        @test compat["julia"] == "1.10"
        @test project["version"] == "0.6.3"
        @test all(
            version -> version in _compat_entries(compat["QUBOTools"]),
            ("0.13", "0.14", "0.15", "0.16"),
        )
        @test "0.6" in _compat_entries(compat["QUBODrivers"])
        @test all(
            version -> version in _compat_entries(compat["ToQUBO"]),
            ("0.4", "0.5", "0.6"),
        )

        docs_project = TOML.parsefile(joinpath(root, "docs", "Project.toml"))
        docs_compat = docs_project["compat"]

        @test docs_compat["QUBO"] == project["version"]
        @test all(
            version -> version in _compat_entries(docs_compat["QUBOTools"]),
            ("0.13", "0.14", "0.15", "0.16"),
        )
        @test "0.6" in _compat_entries(docs_compat["QUBODrivers"])
        @test all(
            version -> version in _compat_entries(docs_compat["ToQUBO"]),
            ("0.4", "0.5", "0.6"),
        )

        @testset "ToQUBO supported versions" begin
            root_spec = Pkg.Types.semver_spec(compat["ToQUBO"])
            docs_spec = Pkg.Types.semver_spec(docs_compat["ToQUBO"])
            @test root_spec == docs_spec
            for spec in (root_spec, docs_spec)
                for version in (v"0.4.0", v"0.4.1", v"0.5.0", v"0.5.2", v"0.6.0", v"0.6.1", v"0.7.1", v"0.7.2", v"0.7.99")
                    @test version in spec
                end
                for version in (v"0.3.9", v"0.7.0", v"0.8.0")
                    @test !(version in spec)
                end
            end
        end

        ci = read(joinpath(root, ".github", "workflows", "ci.yml"), String)
        docs_make = read(joinpath(root, "docs", "make.jl"), String)
        dependabot = read(joinpath(root, ".github", "dependabot.yml"), String)

        @test occursin(r"version:\s*'1\.10'", ci)
        @test occursin(r"version:\s*'1'", ci)

        @test occursin("\"Maintenance Policy\" => \"maintenance.md\"", docs_make)
        @test occursin("package-ecosystem: \"julia\"", dependabot)
        @test occursin("directory: \"/docs\"", dependabot)
        @test occursin("root-julia-dependencies", dependabot)
        @test occursin("docs-julia-dependencies", dependabot)
        @test occursin("package-ecosystem: \"github-actions\"", dependabot)
        @test occursin("interval: \"weekly\"", dependabot)
        @test occursin("interval: \"monthly\"", dependabot)
    end

    return nothing
end
