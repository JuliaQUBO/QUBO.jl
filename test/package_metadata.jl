using TOML

function test_package_metadata()
    @testset "Package Metadata" begin
        root = joinpath(@__DIR__, "..")
        project = TOML.parsefile(joinpath(root, "Project.toml"))
        compat = project["compat"]

        @test compat["julia"] == "1.10"
        @test compat["QUBOTools"] == "0.12"
        @test compat["QUBODrivers"] == "0.4, 0.5"
        @test compat["ToQUBO"] == "0.3"

        ci = read(joinpath(root, ".github", "workflows", "ci.yml"), String)
        docs_make = read(joinpath(root, "docs", "make.jl"), String)
        dependabot = read(joinpath(root, ".github", "dependabot.yml"), String)

        @test occursin(r"version:\s*'1\.10'", ci)
        @test occursin(r"version:\s*'1'", ci)

        @test occursin("\"Dependency Maintenance\" => \"maintenance.md\"", docs_make)
        @test occursin("package-ecosystem: \"julia\"", dependabot)
        @test occursin("directory: \"/docs\"", dependabot)
        @test occursin("package-ecosystem: \"github-actions\"", dependabot)
        @test occursin("interval: \"weekly\"", dependabot)
        @test occursin("interval: \"monthly\"", dependabot)
    end

    return nothing
end
