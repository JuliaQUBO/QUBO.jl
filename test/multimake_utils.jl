include(joinpath(@__DIR__, "..", "docs", "multimake_utils.jl"))

function configure_git_user!()
    run(`git config user.name QUBOTests`)
    run(`git config user.email qubo-tests@example.com`)

    return nothing
end

function commit_file!(name::AbstractString, contents::AbstractString, message::AbstractString)
    write(name, contents)
    run(`git add $name`)
    run(`git commit -m $message`)

    return nothing
end

function initialize_git_repo!()
    run(`git init -b main`)
    configure_git_user!()
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
                    run(`git checkout main`)

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
                        run(`git push -u origin main`)
                        run(`git switch -c gh-multi-pages`)
                        commit_file!("branch.txt", "branch contents\n", "Branch commit")
                        run(`git push -u origin gh-multi-pages`)
                    end
                end

                mktempdir() do clone
                    run(`git clone --branch main --single-branch $origin $clone`)

                    cd(clone) do
                        has_branch = checkout_deploy_branch("gh-multi-pages")

                        @test has_branch
                        @test readchomp(`git branch --show-current`) == "gh-multi-pages"
                        @test chomp(read("branch.txt", String)) == "branch contents"
                        @test success(`git rev-parse --verify refs/heads/gh-multi-pages`)
                    end
                end
            end
        end

        @testset "Uses explicit branch refs with matching tag names and custom remotes" begin
            mktempdir() do remote_path
                mktempdir() do source
                    local tag_commit = ""

                    cd(source) do
                        initialize_git_repo!()
                        run(`git init --bare $remote_path`)
                        run(`git remote add upstream $remote_path`)
                        run(`git push -u upstream main`)
                        run(`git tag gh-multi-pages`)
                        tag_commit = readchomp(`git rev-parse refs/tags/gh-multi-pages`)
                        run(`git push upstream refs/tags/gh-multi-pages`)
                        run(`git switch -c gh-multi-pages`)
                        commit_file!("branch.txt", "branch contents\n", "Branch commit")
                        push_deploy_branch("gh-multi-pages"; remote = "upstream")
                    end

                    mktempdir() do clone
                        run(`git clone --origin upstream --branch main --single-branch $remote_path $clone`)

                        cd(clone) do
                            configure_git_user!()

                            has_branch = checkout_deploy_branch("gh-multi-pages"; remote = "upstream")

                            @test has_branch
                            @test readchomp(`git branch --show-current`) == "gh-multi-pages"
                            @test chomp(read("branch.txt", String)) == "branch contents"

                            commit_file!("branch.txt", "updated branch contents\n", "Update branch contents")
                            push_deploy_branch("gh-multi-pages"; remote = "upstream")
                        end
                    end

                    mktempdir() do verify
                        run(`git clone --origin upstream --branch gh-multi-pages $remote_path $verify`)

                        @test chomp(read(joinpath(verify, "branch.txt"), String)) == "updated branch contents"
                        @test readchomp(`git --git-dir=$remote_path rev-parse refs/tags/gh-multi-pages`) == tag_commit
                    end
                end
            end
        end
    end

    return nothing
end
