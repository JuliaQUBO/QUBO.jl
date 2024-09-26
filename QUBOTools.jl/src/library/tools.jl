@doc raw"""
""" function isapproxdict end

function isapproxdict(x::Dict{K,T}, y::Dict{K,T}; kw...) where {K,T<:Real}
    (length(x) == length(y)) && all(haskey(y, k) && isapprox(x[k], y[k]; kw...) for k in keys(x))
end

@doc raw"""
    _swapdomain(
        source::Type,
        target::Type,
        linear_terms::Dict{Int,T},
        quadratic_terms::Dict{Tuple{Int,Int},T},
        offset::Union{T,Nothing}
    ) where {T}
""" function _swapdomain end

function _swapdomain(
    ::Type{<:SpinDomain},
    ::Type{<:BoolDomain},
    linear_terms::Dict{Int,T},
    quadratic_terms::Dict{Tuple{Int,Int},T},
    offset::Union{T,Nothing},
) where {T}
    bool_offset = isnothing(offset) ? zero(T) : offset
    bool_linear_terms = Dict{Int,T}()
    bool_quadratic_terms = Dict{Tuple{Int,Int},T}()

    for (i, h) in linear_terms
        bool_linear_terms[i] = get(bool_linear_terms, i, zero(T)) + 2h
        bool_offset -= h
    end

    for ((i, j), Q) in quadratic_terms
        bool_quadratic_terms[(i, j)] = get(bool_quadratic_terms, (i, j), zero(T)) + 4Q
        bool_linear_terms[i] = get(bool_linear_terms, i, zero(T)) - 2Q
        bool_linear_terms[j] = get(bool_linear_terms, j, zero(T)) - 2Q
        bool_offset += Q
    end

    return (bool_linear_terms, bool_quadratic_terms, bool_offset)
end

function _swapdomain(
    ::Type{<:BoolDomain},
    ::Type{<:SpinDomain},
    linear_terms::Dict{Int,T},
    quadratic_terms::Dict{Tuple{Int,Int},T},
    offset::Union{T,Nothing}
) where {T}
    spin_offset = isnothing(offset) ? zero(T) : offset
    spin_linear_terms = Dict{Int,T}()
    spin_quadratic_terms = Dict{Tuple{Int,Int},T}()

    for (i, q) in linear_terms
        spin_linear_terms[i] = get(spin_linear_terms, i, zero(T)) + q / 2
        spin_offset += q / 2
    end

    for ((i, j), Q) in quadratic_terms
        spin_quadratic_terms[(i, j)] = get(spin_quadratic_terms, (i, j), zero(T)) + Q / 4
        spin_linear_terms[i] = get(spin_linear_terms, i, zero(T)) + Q / 4
        spin_linear_terms[j] = get(spin_linear_terms, j, zero(T)) + Q / 4
        spin_offset += Q / 4
    end

    return (spin_linear_terms, spin_quadratic_terms, spin_offset)
end

function _map_terms(_linear_terms::Dict{S,T}, _quadratic_terms::Dict{Tuple{S,S},T}, variable_map::Dict{S,Int}) where {S,T}
    linear_terms = Dict{Int,T}(
        variable_map[i] => l
        for (i, l) in _linear_terms
    )
    quadratic_terms = Dict{Tuple{Int,Int},T}(
        (variable_map[i], variable_map[j]) => q
        for ((i, j), q) in _quadratic_terms
    )

    return (linear_terms, quadratic_terms)
end

function _inv_terms(_linear_terms::Dict{Int,T}, _quadratic_terms::Dict{Tuple{Int,Int},T}, variable_inv::Dict{Int,S}) where {S,T}
    linear_terms = Dict{S,T}(
        variable_inv[i] => l
        for (i, l) in _linear_terms
    )
    quadratic_terms = Dict{Tuple{S,S},T}(
        (variable_inv[i], variable_inv[j]) => q
        for ((i, j), q) in _quadratic_terms
    )

    return (linear_terms, quadratic_terms)
end

function _normal_form(_linear_terms::Dict{V,T}, _quadratic_terms::Dict{Tuple{V,V},T}) where {V,T}
    linear_terms = Dict{V,T}()
    quadratic_terms = Dict{Tuple{V,V},T}()
    variable_set = Set{V}()

    sizehint!(linear_terms, length(_linear_terms))
    sizehint!(quadratic_terms, length(_quadratic_terms))

    for (i, l) in _linear_terms
        push!(variable_set, i)

        l += get(linear_terms, i, zero(T))

        if iszero(l)
            delete!(linear_terms, i)
        else
            linear_terms[i] = l
        end
    end

    for ((i, j), q) in _quadratic_terms

        push!(variable_set, i, j)

        if i == j
            q += get(linear_terms, i, zero(T))
            if iszero(q)
                delete!(linear_terms, i)
            else
                linear_terms[i] = q
            end
        elseif i ≺ j
            q += get(quadratic_terms, (i, j), zero(T))
            if iszero(q)
                delete!(quadratic_terms, (i, j))
            else
                quadratic_terms[(i, j)] = q
            end
        else # i > j
            q += get(quadratic_terms, (j, i), zero(T))
            if iszero(q)
                delete!(quadratic_terms, (j, i))
            else
                quadratic_terms[(j, i)] = q
            end
        end
    end

    return (linear_terms, quadratic_terms, variable_set)
end

function _build_mapping(variable_set::Set{V}) where {V}
    variable_map = Dict{V,Int}(
        v => k for (k, v) in enumerate(sort(collect(variable_set); lt=varcmp))
    )
    variable_inv = Dict{Int,V}(v => k for (k, v) in variable_map)

    return (variable_map, variable_inv)
end

@doc raw"""
    infer_model_type(ext::Symbol)
    infer_model_type(path::String)
""" function infer_model_type end

function infer_model_type(path::String)
    _, ext = splitext(path)

    if !isempty(ext)
        # Remove '.' from the beginning
        extsym = Symbol(ext[2:end])

        return infer_model_type(extsym)
    else
        error("Inference Error: Unable to infer model type without file extension")
    end
end

infer_model_type(ext::Symbol) = QUBOTools.infer_model_type(Val(ext))

function infer_model_type(::Val{X}) where {X}
    error("Inference Error: Unable to infer model type from extension '$X'")
end