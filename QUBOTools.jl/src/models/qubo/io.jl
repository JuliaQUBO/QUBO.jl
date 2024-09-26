function Base.write(io::IO, model::QUBO)
    scale = QUBOTools.scale(model)
    offset = QUBOTools.offset(model)
    id = QUBOTools.id(model)
    description = QUBOTools.description(model)
    metadata = QUBOTools.metadata(model)

    if !isnothing(scale)
        println(io, "c scale : $(scale)")
    end

    if !isnothing(offset)
        println(io, "c offset : $(offset)")
    end

    if !isnothing(id)
        println(io, "c id : $(id)")
    end

    if !isnothing(description)
        println(io, "c description : $(description)")
    end

    if !isnothing(metadata)
        for (k, v) in metadata
            print(io, "c $(k) : ")
            JSON.print(io, v)
            println(io)
        end
    end

    println(io, "p qubo 0 $(model.max_index) $(model.num_diagonals) $(model.num_elements)")

    println(io, "c linear terms")
    for (i, q) in QUBOTools.explicit_linear_terms(model)
        println(io, "$(QUBOTools.variable_inv(model, i)) $(QUBOTools.variable_inv(model, i)) $(q)")
    end

    println(io, "c quadratic terms")
    for ((i, j), Q) in QUBOTools.quadratic_terms(model)
        println(io, "$(QUBOTools.variable_inv(model, i)) $(QUBOTools.variable_inv(model, j)) $(Q)")
    end
end

function Base.read(io::IO, ::Type{<:QUBO})
    linear_terms = Dict{Int,Float64}()
    quadratic_terms = Dict{Tuple{Int,Int},Float64}()

    scale = nothing
    offset = nothing

    id = nothing
    description = nothing
    metadata = Dict{String,Any}()

    max_index = nothing
    num_diagonals = nothing
    num_elements = nothing

    for line in strip.(readlines(io))
        if isempty(line)
            continue # ~ skip
        end

        # -*- Comments & Metadata -*-
        m = match(r"^c(\s.*)?$", line)

        if !isnothing(m)
            if isnothing(m[1])
                continue # ~ comment
            end

            # -*- Metadata -*-
            m = match(r"([a-zA-Z][a-zA-Z0-9_]+)\s*:\s*(.+)$", strip(m[1]))
            if !isnothing(m)
                key = string(m[1])
                val = string(m[2])

                if key == "id"
                    id = tryparse(Int, val)
                elseif key == "scale"
                    scale = tryparse(Float64, val)
                elseif key == "offset"
                    offset = tryparse(Float64, val)
                elseif key == "description"
                    description = val
                else
                    metadata[key] = JSON.parse(val)
                end
            end

            continue # ~ comment
        end

        # -*- Problem Header -*-
        m = match(r"^p\s+qubo\s+([+-]?[0-9]+)\s+([+-]?[0-9]+)\s+([+-]?[0-9]+)\s+([+-]?[0-9]+)$", line)

        if !isnothing(m)
            max_index = tryparse(Int, m[2])
            num_diagonals = tryparse(Int, m[3])
            num_elements = tryparse(Int, m[4])
            continue
        end

        # -*- Problem Term -*-
        m = match(r"^([+-]?[0-9]+)\s+([+-]?[0-9]+)\s+([+-]?([0-9]*[.])?[0-9]+)$", line)

        if !isnothing(m)
            i = tryparse(Int, m[1])
            j = tryparse(Int, m[2])
            Q = tryparse(Float64, m[3])

            if isnothing(i) || isnothing(j) || isnothing(Q)
                error("Error: $line")
            end

            if i == j
                linear_terms[i] = get(linear_terms, i, 0.0) + Q
            else
                quadratic_terms[(i, j)] = get(quadratic_terms, (i, j), 0.0) + Q
            end

            continue
        end

        error("Error: '$line'")
    end

    if isnothing(max_index) || isnothing(num_diagonals) || isnothing(num_elements)
        QUBOcodec_error("Invalid problem header")
    end

    QUBO{BoolDomain}(
        linear_terms,
        quadratic_terms;
        scale=scale,
        offset=offset,
        id=id,
        description=description,
        metadata=metadata,
        max_index=max_index,
        num_diagonals=num_diagonals,
        num_elements=num_elements,
    )
end

QUBOTools.infer_model_type(::Val{:qubo}) = QUBO