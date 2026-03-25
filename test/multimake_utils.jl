include(joinpath(@__DIR__, "..", "docs", "multimake_utils.jl"))

function commit_file!(name::AbstractString, contents::AbstractString, message::AbstractString)
    write(name, contents)
    run(`git add $name`)
    run(`git commit -m $message`)

    return nothing
end

function initialize_git_repo!()
    run(`git init -b master`)
    run(`git config user.name QUBOTests`)
    run(`git config user.email qubo-tests@example.com`)
    commit_file!("README.md", "# temp repo\n", "Initial commit")

    return nothing
end

function test_multimake_utils()
    @testset "Multimake Utils" begin
        @testset "Creates orphan branch when target branch is missing" begin
            mktempdir() do repo
                cd(repo) do
                    initialize_git_repo!()

                    has_branch = checkout_deploy_branch("gh-multi-pages")

                    @test !has_branch
                    @test readchomp(`git branch --show-current`) == "gh-multi-pages"
                end
            end
        end

        @testset "Checks out existing target branch" begin
            mktempdir() do repo
                cd(repo) do
                    initialize_git_repo!()
                    run(`git switch -c gh-multi-pages`)
                    commit_file!("branch.txt", "branch contents\n", "Branch commit")
                    run(`git checkout master`)

                    has_branch = checkout_deploy_branch("gh-multi-pages")

                    @test has_branch
                    @test readchomp(`git branch --show-current`) == "gh-multi-pages"
                end
            end
        end

        @testset "Fetches existing remote branch when clone is single-branch" begin
            mktempdir() do origin
                mktempdir() do source
                    cd(source) do
                        initialize_git_repo!()
                        run(`git init --bare $origin`)
                        run(`git remote add origin $origin`)
                        run(`git push -u origin master`)
                        run(`git switch -c gh-multi-pages`)
                        commit_file!("branch.txt", "branch contents\n", "Branch commit")
                        run(`git push -u origin gh-multi-pages`)
                    end
                end

                mktempdir() do clone
                    run(`git clone --branch master --single-branch $origin $clone`)

                    cd(clone) do
                        has_branch = checkout_deploy_branch("gh-multi-pages")

                        @test has_branch
                        @test readchomp(`git branch --show-current`) == "gh-multi-pages"
                        @test read("branch.txt", String) == "branch contents\n"
                        @test success(`git rev-parse --verify refs/heads/gh-multi-pages`)
                    end
                end
            end
        end
    end

    return nothing
end
