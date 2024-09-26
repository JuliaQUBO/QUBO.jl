function Base.write(io::IO, model::HFS)
    if isempty(model)
        @warn "Empty HFS file produced"
        println(io, "0 0")
        return
    end    

    # Output the hfs data file
    # it is a header followed by linear terms and then quadratic terms
    println(io, "$(model.chimera.effective_degree) $(model.chimera.effective_degree)")

    for (i, q) in model.chimera.linear_terms
        args = [
            collect(model.chimera.coordinates[QUBOTools.variable_inv(model, i)]);
            collect(model.chimera.coordinates[QUBOTools.variable_inv(model, i)]);
            q
        ]
        println(io, Printf.@sprintf("%2d %2d %2d %2d    %2d %2d %2d %2d    %8d", args...))
    end

    for ((i, j), Q) in model.chimera.quadratic_terms
        args = [
            collect(model.chimera.coordinates[QUBOTools.variable_inv(model, i)]);
            collect(model.chimera.coordinates[QUBOTools.variable_inv(model, j)]);
            Q
        ]
        println(io, Printf.@sprintf("%2d %2d %2d %2d    %2d %2d %2d %2d    %8d", args...))
    end
end

QUBOTools.infer_model_type(::Val{:hfs}) = HFS