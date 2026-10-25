using TOML
using Pkg

include(joinpath(@__DIR__, "..", "scripts", "verify_zenodo_release.jl"))

_compat_entries(value::AbstractString) = strip.(split(value, ','))

function test_package_metadata()
    @testset "Package Metadata" begin
        root = joinpath(@__DIR__, "..")
        project = TOML.parsefile(joinpath(root, "Project.toml"))
        compat = project["compat"]

        @test compat["julia"] == "1.10"
        @test project["version"] == "0.6.4"
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

        @testset "Citation and release metadata" begin
            read_norm(parts...) = replace(read(joinpath(root, parts...), String), "\r\n" => "\n")

            citation_cff = read_norm("CITATION.cff")
            citation_bib = strip(read_norm("CITATION.bib"))
            readme = read_norm("README.md")
            docs_index = read_norm("docs", "src", "index.md")
            license_text = read_norm("LICENSE")
            checklist = read_norm(".github", "RELEASE_CHECKLIST.md")
            workflow = read_norm(".github", "workflows", "zenodo.yml")

            concept_doi = "10.5281/zenodo.7909165"
            version_doi = "10.5281/zenodo.23649024"
            archived_version = "0.6.4"
            article_doi = "10.1080/10556788.2026.2702926"

            @test occursin("The QUBO Julia module is licensed under the MPL version 2.0:", license_text)
            @test occursin(r"(?m)^license:\s*MPL-2\.0\s*$", citation_cff)
            @test occursin("version: \"$(project["version"])\"", citation_cff)
            @test occursin("doi: \"$concept_doi\"", citation_cff)
            @test occursin("value: \"$version_doi\"", citation_cff)
            @test occursin("description: \"Zenodo DOI for version $archived_version\"", citation_cff)
            @test occursin("doi: \"$article_doi\"", citation_cff)
            @test !occursin("0000-0000-0000-0000", citation_cff)

            @test occursin("@article{qubojl:2026,", citation_bib)
            @test occursin("doi          = {$article_doi}", citation_bib)
            @test occursin("@software{qubo:2023,", citation_bib)
            @test occursin("version      = {v$archived_version}", citation_bib)
            @test occursin("doi          = {$version_doi}", citation_bib)
            @test occursin("note         = {Evergreen concept DOI: $concept_doi}", citation_bib)

            @test occursin("badge/DOI/$concept_doi.svg", readme)
            @test occursin("https://doi.org/$concept_doi", readme)
            @test !occursin("zenodo.org/badge/614041491.svg", readme)

            marker_start = "<!-- citation-policy:start -->"
            marker_end = "<!-- citation-policy:end -->"
            readme_parts = split(readme, marker_start; limit = 2)
            docs_parts = split(docs_index, marker_start; limit = 2)
            @test length(readme_parts) == 2
            @test length(docs_parts) == 2
            readme_section = strip(split(readme_parts[2], marker_end; limit = 2)[1])
            docs_section = strip(split(docs_parts[2], marker_end; limit = 2)[1])
            @test readme_section == docs_section

            bib_match = match(r"(?ms)```bibtex\s*\n(.*?)\n```", readme_section)
            @test bib_match !== nothing
            @test strip(only(bib_match.captures)) == citation_bib

            prose = replace(readme_section, r"(?ms)```bibtex\s*\n.*?\n```" => "")
            @test occursin(article_doi, prose)
            @test occursin(concept_doi, prose)
            @test occursin(version_doi, prose)
            @test occursin("`v$archived_version`", prose)

            @test occursin(concept_doi, checklist)
            @test occursin("Can manage", checklist)
            @test occursin("JuliaQUBO/QUBO.jl#66", checklist)
            @test occursin("Zenodo release verification", checklist)
            @test occursin("cffconvert --validate --infile CITATION.cff", checklist)
            @test occursin("cffconvert\" --validate --infile CITATION.cff", ci)
            @test occursin(r"(?m)^\s*release:\s*$", workflow)
            @test occursin(r"(?m)^\s*-\s*published\s*$", workflow)
            @test occursin(r"(?m)^\s*workflow_run:\s*$", workflow)
            @test occursin(r"(?m)^\s*-\s*TagBot\s*$", workflow)
            @test occursin("scripts/verify_zenodo_release.jl", workflow)

            rec(; concept = "7909165", version = "v0.6.4", doi = version_doi) = Dict{String,Any}(
                "conceptrecid" => concept,
                "doi" => doi,
                "metadata" => Dict{String,Any}("version" => version),
            )
            @test ZenodoReleaseVerification.check_record(rec(), "v0.6.4").ok
            @test !ZenodoReleaseVerification.check_record(rec(; version = "v0.2.0"), "v0.6.4").ok
            @test !ZenodoReleaseVerification.check_record(rec(; concept = "9999999"), "v0.6.4").ok
            @test !ZenodoReleaseVerification.check_record(rec(; doi = concept_doi), "v0.6.4").ok
        end
    end

    return nothing
end
