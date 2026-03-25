function checkout_deploy_branch(branch::AbstractString; remote::AbstractString = "origin")
    if success(`git checkout $branch`)
        return true
    end

    # GitHub Actions checks out only the triggering ref by default, so the
    # deploy branch may exist on the remote but not in the local clone yet.
    if success(`git fetch $remote $branch:$branch`) && success(`git checkout $branch`)
        return true
    end

    if success(`git switch --orphan $branch`)
        return false
    end

    error("Cannot create new orphaned branch $branch.")
end
