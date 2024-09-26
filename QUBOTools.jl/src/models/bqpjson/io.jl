function Base.read(io::IO, M::Type{<:BQPJSON})
    data = JSON.parse(io)

    let report = JSONSchema.validate(BQPJSON_SCHEMA, data)
        if !isnothing(report)
            QUBOcodec_error("Schema violation:\n$(report)")
        end
    end

    # ~*~ Validation ~*~
    id = data["id"]

    version = VersionNumber(data["version"])

    if version !== BQPJSON_VERSION_LATEST
        QUBOcodec_error("Outdated BQPJSON version '$version'")
    end

    variable_domain = data["variable_domain"]

    D = if variable_domain == "boolean"
        BoolDomain
    elseif variable_domain == "spin"
        SpinDomain
    else
        QUBOcodec_error("Inconsistent variable domain '$variable_domain'")
    end

    scale = data["scale"]
    offset = data["offset"]

    if scale < 0.0
        QUBOcodec_error("Negative scale factor '$scale'")
    end

    variable_set = Set{Int}(data["variable_ids"])
    linear_terms = Dict{Int,Float64}(
        i => 0.0 for i in variable_set
    )

    for lt in data["linear_terms"]
        i = lt["id"]
        l = lt["coeff"]

        if i ∉ variable_set
            QUBOcodec_error("Unknown variable id '$i'")
        end

        linear_terms[i] = get(linear_terms, i, 0.0) + l
    end

    quadratic_terms = Dict{Tuple{Int,Int},Float64}()

    for qt in data["quadratic_terms"]
        i = qt["id_head"]
        j = qt["id_tail"]
        q = qt["coeff"]

        if i == j
            QUBOcodec_error("Twin quadratic term '$i, $j'")
        elseif i ∉ variable_set
            QUBOcodec_error("Unknown variable id '$i'")
        elseif j ∉ variable_set
            QUBOcodec_error("Unknown variable id '$j'")
        elseif j ≺ i
            i, j = j, i
        end

        quadratic_terms[(i, j)] = get(quadratic_terms, (i, j), 0.0) + q
    end

    description = get(data, "description", nothing)
    metadata = deepcopy(data["metadata"])
    solutions = get(data, "solutions", nothing)

    if !isnothing(solutions)
        sol_ids = Set{Int}()
        for solution in data["solutions"]
            i = solution["id"]

            if i ∈ sol_ids
                error("Invalid data: Duplicate solution id '$i'")
                push!(sol_ids, i)
            end

            var_ids = Set{Int}()

            for assign in solution["assignment"]
                j = assign["id"]
                v = assign["value"]

                if j ∉ variable_set
                    error("Invalid data: Unknown variable id '$j' in assignment")
                elseif j ∈ var_ids
                    error("Invalid data: Duplicate variable id '$j' in assignment")
                elseif !BQPJSON_VALIDATE_DOMAIN(v, D)
                    error("Invalid data: Variable assignment '$value' out of domain")
                end

                push!(var_ids, j)
            end

            if length(var_ids) != length(variable_set)
                error("Invalid data: Length mismatch between variable set and solution assignment")
            end
        end
    end

    model = BQPJSON{D}(
        linear_terms,
        quadratic_terms;
        scale=scale,
        offset=offset,
        id=id,
        version=version,
        description=description,
        metadata=metadata,
        solutions=solutions
    )

    convert(M, model)
end

function Base.write(io::IO, model::BQPJSON{D}) where {D<:VariableDomain}
    linear_terms = Dict{String,Any}[]
    quadratic_terms = Dict{String,Any}[]
    offset = QUBOTools.offset(model)
    scale = QUBOTools.scale(model)
    id = QUBOTools.id(model)
    version = QUBOTools.version(model)
    variable_domain = BQPJSON_VARIABLE_DOMAIN(D)
    metadata = QUBOTools.metadata(model)

    for (i, l) in QUBOTools.linear_terms(model)
        push!(
            linear_terms,
            Dict{String,Any}(
                "id" => QUBOTools.variable_inv(model, i),
                "coeff" => l,
            )
        )
    end

    for ((i, j), q) in QUBOTools.quadratic_terms(model)
        push!(
            quadratic_terms,
            Dict{String,Any}(
                "id_head" => QUBOTools.variable_inv(model, i),
                "id_tail" => QUBOTools.variable_inv(model, j),
                "coeff" => q,
            )
        )
    end

    sort!(linear_terms; by=(lt) -> lt["id"])
    sort!(quadratic_terms; by=(qt) -> (qt["id_head"], qt["id_tail"]))

    variable_ids = QUBOTools.variables(model)

    data = Dict{String,Any}(
        "id" => id,
        "version" => string(version),
        "variable_domain" => variable_domain,
        "linear_terms" => linear_terms,
        "quadratic_terms" => quadratic_terms,
        "variable_ids" => variable_ids,
        "offset" => offset,
        "scale" => scale,
        "metadata" => metadata,
    )

    description = QUBOTools.description(model)

    if !isnothing(description)
        data["description"] = description
    end

    if !isnothing(model.solutions)
        data["solutions"] = deepcopy(model.solutions)
    else
        sampleset = QUBOTools.sampleset(model)

        if !isnothing(sampleset)
            id = 0

            solutions = Dict{String,Any}[]

            for sample in sampleset
                assignment = Dict{String,Any}[
                    Dict{String,Any}(
                        "id" => i,
                        "value" => sample.state[j]
                    ) for (i, j) in QUBOTools.variable_map(model)
                ]
                for _ = 1:sample.reads
                    push!(
                        solutions,
                        Dict{String,Any}(
                            "id" => (id += 1),
                            "assignment" => assignment,
                            "evaluation" => sample.value,
                        )
                    )
                end
            end

            data["solutions"] = solutions
        end
    end

    JSON.print(io, data)
end

function Base.convert(::Type{<:BQPJSON{B}}, model::BQPJSON{A}) where {A,B}
    backend = convert(BQPJSON_BACKEND_TYPE{B}, model.backend)
    solutions = deepcopy(model.solutions)

    if !isnothing(solutions)
        for solution in solutions
            for assign in solution["assignment"]
                assign["value"] = BQPJSON_SWAP_DOMAIN(assign["value"], A)
            end
        end
    end

    BQPJSON{B}(backend; solutions=solutions)
end

function Base.copy!(
    target::BQPJSON{D},
    source::BQPJSON{D},
) where {D<:VariableDomain}
    copy!(QUBOTools.backend(target), QUBOTools.backend(source))

    target.solutions = deepcopy(source.solutions)

    target
end

QUBOTools.infer_model_type(::Val{:json}) = BQPJSON