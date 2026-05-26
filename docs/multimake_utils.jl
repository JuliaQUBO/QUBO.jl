branch_ref(branch::AbstractString) = "refs/heads/$branch"
has_local_branch(branch::AbstractString) = success(`git show-ref --verify --quiet $(branch_ref(branch))`)

function checkout_deploy_branch(branch::AbstractString; remote::AbstractString = "origin")
    if has_local_branch(branch) && success(`git checkout $branch`)
        return true
    end

    # GitHub Actions checks out only the triggering ref by default, so the
    # deploy branch may exist on the remote but not in the local clone yet.
    ref = branch_ref(branch)

    if success(`git fetch $remote $ref:$ref`) &&
       has_local_branch(branch) &&
       success(`git checkout $branch`)
        return true
    end

    if success(`git switch --orphan $branch`)
        return false
    end

    error("Cannot create new orphaned branch $branch.")
end

function push_deploy_branch(branch::AbstractString; remote::AbstractString = "origin")
    run(`git push $remote HEAD:$(branch_ref(branch))`)

    return nothing
end

function restore_source_branch(branch::AbstractString; remote::AbstractString = "origin")
    if has_local_branch(branch) ||
       success(`git fetch $remote $(branch_ref(branch)):$(branch_ref(branch))`)
        run(`git checkout $branch`)

        return true
    end

    return false
end
