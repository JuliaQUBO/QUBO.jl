""" /src/interface/data.jl @ QUBOTools.jl

    This file contains iterfaces for data access within QUBO's format system.
    
    It also contains a few ones for executing queries on models.
"""

@doc raw"""
    backend(model)::AbstractQUBOModel
    backend(model::AbstractQUBOModel)::AbstractQUBOModel

Retrieves the model's backend.
Implementing this function allows one to profit from fallback implementations of the other methods.
""" function backend end

# ~*~ Data access ~*~ #
@doc raw"""
    model_name(model)::String

Returns a string representing the model type.
""" function model_name end

@doc raw"""
    domain(model)::VariableDomain

Returns the type representing the variable domain of a given model.
""" function domain end

@doc raw"""
    domain_name(model)::String

Returns a string representing the variable domain.
""" function domain_name end

@doc raw"""
    swap_domain(source, target, model)
    swap_domain(source, target, state)
    swap_domain(source, target, states)
    swap_domain(source, target, sampleset)

Returns a new object, switching its domain from `source` to `target`.
""" function swap_domain end

@doc raw"""
    offset(model)::T where {T <: Real}

""" function offset end

@doc raw"""
    scale(model)::T where {T <: Real}

""" function scale end

@doc raw"""
    id(model)::Integer
""" function id end

@doc raw"""
    version(model)::Union{VersionNumber, Nothing}
""" function version end

@doc raw"""
    description(model)::Union{String, Nothing}
""" function description end

@doc raw"""
    metadata(model)::Dict{String, Any}
""" function metadata end

@doc raw"""
    sampleset(model)::QUBOTools.SampleSet
""" function sampleset end

@doc raw"""
    linear_terms(model)::Dict{Int,T} where {T <: Real}

Retrieves the linear terms of a model as a dict.

!!! The `explicit_linear_terms` method includes all variables, breaking linear sparsity.
""" function linear_terms end

@doc raw"""
    explicit_linear_terms(model)::Dict{Int,T} where {T <: Real}

Retrieves the linear terms of a model as a dict, including zero entries.
""" function explicit_linear_terms end

@doc raw"""
    quadratic_terms(model)::Dict{Tuple{Int,Int},T} where {T <: Real}

Retrieves the quadratic terms of a model as a dict.
For every key pair ``(i, j)`` holds that ``i < j``.
""" function quadratic_terms end

@doc raw"""
    variables(model)::Vector

Returns a sorted vector containing the model's variables.
If order doesn't matter, use `variable_set(model)` instead.
""" function variables end

@doc raw"""
    variable_set(model)::Set

Returns the set of variables of a given model.
""" function variable_set end

@doc raw"""
    variable_map(model)::Dict{V,Int} where {V}
    variable_map(model, x::V)::Integer where {V}

""" function variable_map end

@doc raw"""
    variable_inv(model)::Dict{Int,V} where {V}
    variable_inv(model, i::Integer)::V where {V}
""" function variable_inv end

# ~*~ Model's Normal Forms ~*~ #
@doc raw"""
    qubo(model::AbstractQUBOModel{<:BoolDomain})
    qubo(::Type{<:Dict}, T::Type, model::AbstractQUBOModel{<:BoolDomain})
    qubo(::Type{<:Array}, T::Type, model::AbstractQUBOModel{<:BoolDomain})

# QUBO Normal Form

```math
f(\vec{x}) = \alpha \left[{ \vec{x}'\,Q\,\vec{x} + \beta }\right]
```

Returns a triple ``(Q, \alpha, \beta)`` where:
 * `Q::Dict{Tuple{Int, Int}, T}` is a sparse representation of the QUBO Matrix.
 * `α::T` is the scaling factor.
 * `β::T` is the offset constant.

!!! The main diagonal is explicitly included, breaking sparsity by containing zero entries.
""" function qubo end

@doc raw"""
    ising(model::AbstractQUBOModel{<:SpinDomain})
    ising(::Type{<:Dict}, model::AbstractQUBOModel{<:SpinDomain})
    ising(::Type{<:Array}, model::AbstractQUBOModel{<:SpinDomain})

# Ising Normal Form

```math
H(\vec{s}) = \alpha \left[{ \vec{s}'\,J\,\vec{s} + \vec{h}\,\vec{s} + \beta }\right]
```

Returns a quadruple ``(h, J, \alpha, \beta)`` where:
* `h::Dict{Int, T}` is a sparse vector for the linear terms of the Ising Model.
* `J::Dict{Tuple{Int, Int}, T}` is a sparse representation of the quadratic magnetic interactions.
* `α::T` is the scaling factor.
* `β::T` is the offset constant.

!!! The main diagonal is explicitly included, breaking sparsity by containing zero entries.
""" function ising end

# ~*~ Data queries ~*~ #
@doc raw"""
    energy(state, model)::T
    energy(state, Q::Dict{Tuple{Int,Int},T})
    energy(state, h::Dict{Int,T}, J::Dict{Tuple{Int,Int},T})

This function aims to evaluate the energy of a given state under some QUBO Model.
**Note:** Scale and offset factors are taken into account.
""" function energy end

# ~*~ Queries: sizes & density ~*~ #
@doc raw"""
    domain_size(model)::Integer

Counts the number of variables in the model.
""" function domain_size end

@doc raw"""
    linear_size(model)::Int

Counts the number of non-zero linear terms in the model.
""" function linear_size end

@doc raw"""
    quadratic_size(model)::Int

Counts the number of non-zero quadratic terms in the model.
""" function quadratic_size end

@doc raw"""
    density(model)::Float64

Computes the density ``\rho`` of non-zero terms in a model, according to the expression
```math
\rho = \frac{2Q + L}{N^{2}}
```
where ``l`` is the number of linear terms, ``Q`` the number of quadratic ones and ``N`` the number of variables.

If the model is empty, returns `NaN`.
""" function density end

@doc raw"""
    linear_density(model)::Float64

""" function linear_density end

@doc raw"""
    quadratic_density(model)::Float64

""" function quadratic_density end

@doc raw"""
    adjacency(model)::Dict{Int,Set{Int}}
    adjacency(model, i::Integer)::Set{Int}
    adjacency(Q::Dict{Tuple{Int,Int},T})::Dict{Int,Set{Int}}
    adjacency(Q::Dict{Tuple{Int,Int},T}, i::Integer)::Set{Int}
""" function adjacency end

# ~*~ Internal: bridge validation ~*~ #
@doc raw"""
    __isvalidbridge(source::M, target::M, ::Type{<:AbstractQUBOModel}; kws...) where M <: AbstractQUBOModel

Checks if the `source` model is equivalent to the `target` reference modulo the given origin type.
Key-word arguments `kws...` are passed to interal `isapprox(::T, ::T; kws...)` calls.

""" function __isvalidbridge end