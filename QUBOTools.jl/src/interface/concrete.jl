# ~*~ SampleSet ~*~ #

# -*- Short-circuits:
QUBOTools.swap_domain(
    ::Type{D},
    ::Type{D},
    state::Vector{U}
) where {D<:VariableDomain,U<:Integer} = state

QUBOTools.swap_domain(
    ::Type{D},
    ::Type{D},
    states::Vector{Vector{U}}
) where {D<:VariableDomain,U<:Integer} = states

QUBOTools.swap_domain(
    ::Type{D},
    ::Type{D},
    sampleset::SampleSet
) where {D<:VariableDomain} = sampleset

function QUBOTools.swap_domain(::Type{SpinDomain}, ::Type{BoolDomain}, state::Vector{U}) where {U<:Integer}
    # ~ x = (s + 1) ÷ 2 ~ #
    return (state .+ 1) .÷ 2
end

function QUBOTools.swap_domain(::Type{BoolDomain}, ::Type{SpinDomain}, state::Vector{U}) where {U<:Integer}
    # ~ s = 2x - 1 ~ #
    return (2 .* state) .- 1
end

function QUBOTools.swap_domain(
    ::Type{A},
    ::Type{B},
    states::Vector{Vector{U}}
) where {A<:VariableDomain,B<:VariableDomain,U<:Integer}
    return Vector{U}[QUBOTools.swap_domain(A, B, state) for state in states]
end

function QUBOTools.swap_domain(
    ::Type{A},
    ::Type{B},
    sampleset::SampleSet{U,T}
) where {A<:VariableDomain,B<:VariableDomain,U<:Integer,T<:Real}
    return SampleSet{U,T}(
        Sample{U,T}[
            Sample{U,T}(
                QUBOTools.swap_domain(A, B, sample.state),
                sample.reads,
                sample.value,
            )
            for sample in sampleset
        ],
        deepcopy(sampleset.metadata)
    )
end

function QUBOTools.energy(state::Vector{U}, Q::Dict{Tuple{Int,Int},T}) where {U<:Integer,T<:Real}
    s = zero(T)

    for ((i, j), c) in Q
        s += state[i] * state[j] * c
    end

    return s
end

function QUBOTools.energy(state::Vector{U}, h::Dict{Int,T}, J::Dict{Tuple{Int,Int},T}) where {U<:Integer,T<:Real}
    s = zero(T)

    for (i, c) in h
        s += state[i] * c
    end

    for ((i, j), c) in J
        s += state[i] * state[j] * c
    end

    return s
end

function QUBOTools.adjacency(Q::Dict{Tuple{Int,Int},<:Real})
    A = Dict{Int,Set{Int}}()

    for (i, j) in keys(Q)
        if i == j
            continue
        end

        if !haskey(A, i)
            A[i] = Set{Int}()
        end

        if !haskey(A, j)
            A[j] = Set{Int}()
        end

        push!(A[i], j)
        push!(A[j], i)
    end

    return A
end

function QUBOTools.adjacency(Q::Dict{Tuple{Int,Int},<:Real}, k::Integer)
    A = Set{Int}()

    for (i, j) in keys(Q)
        if i == j
            continue
        end

        if i == k
            push!(A, j)
        end
    end

    return A
end