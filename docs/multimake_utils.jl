function checkout_deploy_branch(branch::AbstractString)
    if success(`git checkout $branch`)
        return true
    end

    if success(`git switch --orphan $branch`)
        return false
    end

    error("Cannot create new orphaned branch $branch.")
end
