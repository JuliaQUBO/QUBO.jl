module Karp21

import JuMP
import MathOptInterface as MOI
import ..ToQUBO
import ..ExactSampler

export PROBLEMS
export satisfiability, sat, three_sat
export zero_one_integer_programming, integer_programming
export clique, independent_set, vertex_cover
export set_packing, set_cover, exact_cover, hitting_set, three_dimensional_matching, three_d_matching
export feedback_vertex_set, feedback_arc_set
export directed_hamiltonian_cycle, hamiltonian_cycle, hamiltonian_path, travelling_salesman
export chromatic_number, graph_coloring, clique_cover
export steiner_tree
export knapsack, subset_sum, number_partition, job_sequencing
export max_cut

function _new_model(optimizer)
    return isnothing(optimizer) ? JuMP.Model() : JuMP.Model(optimizer)
end

function _normalize_edges(
    num_vertices::Integer,
    edges::AbstractVector;
    directed::Bool = false,
)
    n = Int(num_vertices)
    n >= 1 || throw(ArgumentError("num_vertices must be at least 1, got $(n)"))
    normalized = Tuple{Int, Int}[]
    seen = Set{Tuple{Int, Int}}()
    for e in edges
        u, v = if e isa Pair
            Int(first(e)), Int(last(e))
        elseif (e isa Tuple || e isa AbstractVector) && length(e) == 2
            Int(e[1]), Int(e[2])
        else
            throw(ArgumentError("each edge must be a 2-tuple, Pair, or 2-element vector; got $(repr(e))"))
        end
        (1 <= u <= n && 1 <= v <= n) ||
            throw(ArgumentError("edge ($(u), $(v)) has vertex outside 1:$(n)"))
        if !directed
            u == v && continue
            pair = u < v ? (u, v) : (v, u)
            if !(pair in seen)
                push!(seen, pair)
                push!(normalized, pair)
            end
        else
            pair = (u, v)
            if !(pair in seen)
                push!(seen, pair)
                push!(normalized, pair)
            end
        end
    end
    return normalized
end

function _edges_and_weights_from_matrix(
    adj::AbstractMatrix{<:Real};
    directed::Bool = false,
)
    n, m = size(adj)
    n == m || throw(ArgumentError("adjacency matrix must be square, got size $(size(adj))"))
    edges = Tuple{Int, Int}[]
    weights = Float64[]
    if directed
        for u in 1:n, v in 1:n
            w = Float64(adj[u, v])
            if !iszero(w)
                push!(edges, (u, v))
                push!(weights, w)
            end
        end
    else
        for u in 1:n, v in (u + 1):n
            w = Float64(adj[u, v] != 0 ? adj[u, v] : adj[v, u])
            if !iszero(w)
                push!(edges, (u, v))
                push!(weights, w)
            end
        end
    end
    return n, edges, weights
end

function _default_weights(count::Int, weights::Union{Nothing, AbstractVector{<:Real}})
    if isnothing(weights)
        return ones(Float64, count)
    end
    length(weights) == count ||
        throw(ArgumentError("weights length ($(length(weights))) must match count ($(count))"))
    return Float64.(weights)
end

function _literal_expr(x::AbstractVector{JuMP.VariableRef}, lit::Integer)
    idx = abs(Int(lit))
    1 <= idx <= length(x) ||
        throw(ArgumentError("literal $(lit) references variable outside 1:$(length(x))"))
    return lit > 0 ? x[idx] : (1 - x[idx])
end

"""
    Karp21.satisfiability(num_variables, clauses; hard_clauses=true, optimizer=nothing)

Build a JuMP model for Karp #1 (**Satisfiability** / **Max-SAT**).
Each clause in `clauses` is a vector of signed integer literals in `±(1:num_variables)`.
When `hard_clauses=true` (default), every clause is registered as a hard constraint
`sum(lits) >= 1`. When `hard_clauses=false`, auxiliary clause indicators `y[c]` are
maximized (`Max-SAT`).
"""
function satisfiability(
    num_variables::Integer,
    clauses::AbstractVector{<:AbstractVector{<:Integer}};
    hard_clauses::Bool = true,
    optimizer = nothing,
)
    n = Int(num_variables)
    n >= 1 || throw(ArgumentError("num_variables must be at least 1"))
    isempty(clauses) && throw(ArgumentError("clauses must not be empty"))

    model = _new_model(optimizer)
    JuMP.@variable(model, x[1:n], Bin)

    if hard_clauses
        JuMP.@constraint(
            model,
            clause_satisfied[c in eachindex(clauses)],
            sum(_literal_expr(x, lit) for lit in clauses[c]) >= 1
        )
        JuMP.@objective(model, Min, 0.0)
    else
        m = length(clauses)
        JuMP.@variable(model, y[1:m], Bin)
        JuMP.@constraint(
            model,
            clause_indicator[c in 1:m],
            y[c] <= sum(_literal_expr(x, lit) for lit in clauses[c])
        )
        JuMP.@objective(model, Max, sum(y))
    end

    return model
end

const sat = satisfiability

"""
    Karp21.three_sat(num_variables, clauses; hard_clauses=true, optimizer=nothing)

Build a JuMP model for Karp #11 (**3-Satisfiability** / **3-SAT**).
Validates that every clause has between 1 and 3 literals before delegating to
[`satisfiability`](@ref).
"""
function three_sat(
    num_variables::Integer,
    clauses::AbstractVector{<:AbstractVector{<:Integer}};
    hard_clauses::Bool = true,
    optimizer = nothing,
)
    for (idx, clause) in enumerate(clauses)
        (1 <= length(clause) <= 3) ||
            throw(ArgumentError("3-SAT clause $(idx) must have 1 to 3 literals, got $(length(clause))"))
    end
    return satisfiability(num_variables, clauses; hard_clauses = hard_clauses, optimizer = optimizer)
end

"""
    Karp21.zero_one_integer_programming(A, b; c=nothing, sense=:EqualTo, objective_sense=MOI.MIN_SENSE, optimizer=nothing)

Build a JuMP model for Karp #2 (**0-1 Integer Programming**).
Registers linear constraints `A * x == b` (`sense=:EqualTo`), `A * x <= b` (`sense=:LessThan`),
or `A * x >= b` (`sense=:GreaterThan`) over binary variables `x[1:n]`.
"""
function zero_one_integer_programming(
    A::AbstractMatrix{<:Real},
    b::AbstractVector{<:Real};
    c::Union{Nothing, AbstractVector{<:Real}} = nothing,
    sense::Symbol = :EqualTo,
    objective_sense::MOI.OptimizationSense = MOI.MIN_SENSE,
    optimizer = nothing,
)
    m, n = size(A)
    length(b) == m || throw(ArgumentError("b length ($(length(b))) must match row count of A ($(m))"))
    obj_c = isnothing(c) ? zeros(Float64, n) : _default_weights(n, c)

    model = _new_model(optimizer)
    JuMP.@variable(model, x[1:n], Bin)

    if sense == :EqualTo
        JuMP.@constraint(model, linear_eq[i in 1:m], sum(A[i, j] * x[j] for j in 1:n) == b[i])
    elseif sense == :LessThan
        JuMP.@constraint(model, linear_le[i in 1:m], sum(A[i, j] * x[j] for j in 1:n) <= b[i])
    elseif sense == :GreaterThan
        JuMP.@constraint(model, linear_ge[i in 1:m], sum(A[i, j] * x[j] for j in 1:n) >= b[i])
    else
        throw(ArgumentError("sense must be :EqualTo, :LessThan, or :GreaterThan; got $(repr(sense))"))
    end

    if objective_sense == MOI.MIN_SENSE
        JuMP.@objective(model, Min, sum(obj_c[j] * x[j] for j in 1:n))
    elseif objective_sense == MOI.MAX_SENSE
        JuMP.@objective(model, Max, sum(obj_c[j] * x[j] for j in 1:n))
    else
        throw(ArgumentError("objective_sense must be MOI.MIN_SENSE or MOI.MAX_SENSE"))
    end

    return model
end

const integer_programming = zero_one_integer_programming

"""
    Karp21.clique(num_vertices, edges; weights=nothing, target_size=nothing, optimizer=nothing)
    Karp21.clique(adj_matrix; weights=nothing, target_size=nothing, optimizer=nothing)

Build a JuMP model for Karp #3 (**Clique** / **Maximum Weight Clique**).
Registers non-edge exclusion constraints `x[u] + x[v] <= 1` for every non-adjacent pair `(u, v)`
and maximizes `sum(weights[v] * x[v])`.
"""
function clique(
    num_vertices::Integer,
    edges::AbstractVector;
    weights::Union{Nothing, AbstractVector{<:Real}} = nothing,
    target_size::Union{Nothing, Integer} = nothing,
    optimizer = nothing,
)
    n = Int(num_vertices)
    norm_edges = _normalize_edges(n, edges; directed = false)
    edge_set = Set(norm_edges)
    w = _default_weights(n, weights)

    non_edges = Tuple{Int, Int}[
        (u, v) for u in 1:n for v in (u + 1):n if !((u, v) in edge_set)
    ]

    model = _new_model(optimizer)
    JuMP.@variable(model, x[1:n], Bin)
    JuMP.@constraint(model, non_edge[(u, v) in non_edges], x[u] + x[v] <= 1)
    if !isnothing(target_size)
        JuMP.@constraint(model, clique_size, sum(x) == Int(target_size))
    end
    JuMP.@objective(model, Max, sum(w[v] * x[v] for v in 1:n))
    return model
end

function clique(
    adj::AbstractMatrix{<:Real};
    weights::Union{Nothing, AbstractVector{<:Real}} = nothing,
    target_size::Union{Nothing, Integer} = nothing,
    optimizer = nothing,
)
    n, edges, _ = _edges_and_weights_from_matrix(adj; directed = false)
    return clique(n, edges; weights = weights, target_size = target_size, optimizer = optimizer)
end

"""
    Karp21.independent_set(num_vertices, edges; weights=nothing, optimizer=nothing)
    Karp21.independent_set(adj_matrix; weights=nothing, optimizer=nothing)

Build a JuMP model for **Maximum Independent Set** (complement of [`clique`](@ref)).
Registers edge conflict constraints `x[u] + x[v] <= 1` for every `(u, v) in edges`.
"""
function independent_set(
    num_vertices::Integer,
    edges::AbstractVector;
    weights::Union{Nothing, AbstractVector{<:Real}} = nothing,
    optimizer = nothing,
)
    n = Int(num_vertices)
    norm_edges = _normalize_edges(n, edges; directed = false)
    w = _default_weights(n, weights)

    model = _new_model(optimizer)
    JuMP.@variable(model, x[1:n], Bin)
    JuMP.@constraint(model, edge_conflict[(u, v) in norm_edges], x[u] + x[v] <= 1)
    JuMP.@objective(model, Max, sum(w[v] * x[v] for v in 1:n))
    return model
end

function independent_set(
    adj::AbstractMatrix{<:Real};
    weights::Union{Nothing, AbstractVector{<:Real}} = nothing,
    optimizer = nothing,
)
    n, edges, _ = _edges_and_weights_from_matrix(adj; directed = false)
    return independent_set(n, edges; weights = weights, optimizer = optimizer)
end

"""
    Karp21.set_packing(universe, subsets; weights=nothing, optimizer=nothing)

Build a JuMP model for Karp #4 (**Set Packing**).
Registers pairwise disjointness constraints `x[i] + x[j] <= 1` for overlapping subsets
and maximizes `sum(weights[j] * x[j])`.
"""
function set_packing(
    universe::AbstractVector,
    subsets::AbstractVector{<:AbstractVector};
    weights::Union{Nothing, AbstractVector{<:Real}} = nothing,
    optimizer = nothing,
)
    m = length(subsets)
    m >= 1 || throw(ArgumentError("subsets must not be empty"))
    w = _default_weights(m, weights)
    universe_set = Set(universe)
    for (j, s) in enumerate(subsets)
        all(elem -> elem in universe_set, s) ||
            throw(ArgumentError("subset $(j) contains elements outside universe"))
    end

    subset_sets = [Set(s) for s in subsets]
    overlapping_pairs = Tuple{Int, Int}[
        (i, j) for i in 1:m for j in (i + 1):m if !isempty(intersect(subset_sets[i], subset_sets[j]))
    ]

    model = _new_model(optimizer)
    JuMP.@variable(model, x[1:m], Bin)
    JuMP.@constraint(model, disjoint_pair[(i, j) in overlapping_pairs], x[i] + x[j] <= 1)
    JuMP.@objective(model, Max, sum(w[j] * x[j] for j in 1:m))
    return model
end

"""
    Karp21.vertex_cover(num_vertices, edges; weights=nothing, optimizer=nothing)
    Karp21.vertex_cover(adj_matrix; weights=nothing, optimizer=nothing)

Build a JuMP model for Karp #5 (**Node Cover** / **Minimum Vertex Cover**).
Registers edge coverage constraints `x[u] + x[v] >= 1` for every `(u, v) in edges`
and minimizes `sum(weights[v] * x[v])`.
"""
function vertex_cover(
    num_vertices::Integer,
    edges::AbstractVector;
    weights::Union{Nothing, AbstractVector{<:Real}} = nothing,
    optimizer = nothing,
)
    n = Int(num_vertices)
    norm_edges = _normalize_edges(n, edges; directed = false)
    w = _default_weights(n, weights)

    model = _new_model(optimizer)
    JuMP.@variable(model, x[1:n], Bin)
    JuMP.@constraint(model, edge_cover[(u, v) in norm_edges], x[u] + x[v] >= 1)
    JuMP.@objective(model, Min, sum(w[v] * x[v] for v in 1:n))
    return model
end

function vertex_cover(
    adj::AbstractMatrix{<:Real};
    weights::Union{Nothing, AbstractVector{<:Real}} = nothing,
    optimizer = nothing,
)
    n, edges, _ = _edges_and_weights_from_matrix(adj; directed = false)
    return vertex_cover(n, edges; weights = weights, optimizer = optimizer)
end

"""
    Karp21.set_cover(universe, subsets; weights=nothing, optimizer=nothing)

Build a JuMP model for Karp #6 (**Set Covering**).
Registers element coverage constraints `sum(x[j] for j with e in subsets[j]) >= 1` for each
`e in universe` and minimizes `sum(weights[j] * x[j])`.
"""
function set_cover(
    universe::AbstractVector,
    subsets::AbstractVector{<:AbstractVector};
    weights::Union{Nothing, AbstractVector{<:Real}} = nothing,
    optimizer = nothing,
)
    m = length(subsets)
    m >= 1 || throw(ArgumentError("subsets must not be empty"))
    w = _default_weights(m, weights)
    subset_sets = [Set(s) for s in subsets]

    for e in universe
        any(e in s for s in subset_sets) ||
            throw(ArgumentError("universe element $(repr(e)) is not covered by any subset"))
    end

    model = _new_model(optimizer)
    JuMP.@variable(model, x[1:m], Bin)
    JuMP.@constraint(
        model,
        cover_elem[i in eachindex(universe)],
        sum(x[j] for j in 1:m if universe[i] in subset_sets[j]) >= 1
    )
    JuMP.@objective(model, Min, sum(w[j] * x[j] for j in 1:m))
    return model
end

"""
    Karp21.feedback_vertex_set(num_vertices, directed_edges; weights=nothing, optimizer=nothing)

Build a JuMP model for Karp #7 (**Feedback Node Set** / **Directed Feedback Vertex Set**).
Uses binary removal variables `x[v]` and tournament ordering variables `p[u, v]` (`u < v`)
with transitivity constraints so that remaining vertices admit a topological ordering.
"""
function feedback_vertex_set(
    num_vertices::Integer,
    directed_edges::AbstractVector;
    weights::Union{Nothing, AbstractVector{<:Real}} = nothing,
    optimizer = nothing,
)
    n = Int(num_vertices)
    edges = _normalize_edges(n, directed_edges; directed = true)
    w = _default_weights(n, weights)

    pairs = Tuple{Int, Int}[(u, v) for u in 1:n for v in (u + 1):n]
    triples = Tuple{Int, Int, Int}[
        (u, v, k) for u in 1:n for v in (u + 1):n for k in (v + 1):n
    ]

    model = _new_model(optimizer)
    JuMP.@variable(model, x[1:n], Bin)
    JuMP.@variable(model, p[pair in pairs], Bin)

    for (u, v, k) in triples
        JuMP.@constraint(model, p[(u, v)] + p[(v, k)] - p[(u, k)] >= 0)
        JuMP.@constraint(model, p[(u, v)] + p[(v, k)] - p[(u, k)] <= 1)
    end

    for (u, v) in edges
        if u == v
            JuMP.@constraint(model, x[u] >= 1)
        elseif u < v
            JuMP.@constraint(model, p[(u, v)] + x[u] + x[v] >= 1)
        else
            JuMP.@constraint(model, (1 - p[(v, u)]) + x[u] + x[v] >= 1)
        end
    end

    JuMP.@objective(model, Min, sum(w[v] * x[v] for v in 1:n))
    return model
end

"""
    Karp21.feedback_arc_set(num_vertices, directed_edges; weights=nothing, optimizer=nothing)

Build a JuMP model for Karp #8 (**Feedback Arc Set** / **Directed Feedback Edge Set**).
Uses binary arc-removal variables `y[e]` for each edge `e` and tournament ordering variables
`p[u, v]` (`u < v`) with transitivity constraints.
"""
function feedback_arc_set(
    num_vertices::Integer,
    directed_edges::AbstractVector;
    weights::Union{Nothing, AbstractVector{<:Real}} = nothing,
    optimizer = nothing,
)
    n = Int(num_vertices)
    edges = _normalize_edges(n, directed_edges; directed = true)
    m = length(edges)
    m >= 1 || throw(ArgumentError("directed_edges must not be empty"))
    w = _default_weights(m, weights)

    pairs = Tuple{Int, Int}[(u, v) for u in 1:n for v in (u + 1):n]
    triples = Tuple{Int, Int, Int}[
        (u, v, k) for u in 1:n for v in (u + 1):n for k in (v + 1):n
    ]

    model = _new_model(optimizer)
    JuMP.@variable(model, y[1:m], Bin)
    JuMP.@variable(model, p[pair in pairs], Bin)

    for (u, v, k) in triples
        JuMP.@constraint(model, p[(u, v)] + p[(v, k)] - p[(u, k)] >= 0)
        JuMP.@constraint(model, p[(u, v)] + p[(v, k)] - p[(u, k)] <= 1)
    end

    for (idx, (u, v)) in enumerate(edges)
        if u == v
            JuMP.@constraint(model, y[idx] >= 1)
        elseif u < v
            JuMP.@constraint(model, p[(u, v)] + y[idx] >= 1)
        else
            JuMP.@constraint(model, (1 - p[(v, u)]) + y[idx] >= 1)
        end
    end

    JuMP.@objective(model, Min, sum(w[idx] * y[idx] for idx in 1:m))
    return model
end

"""
    Karp21.directed_hamiltonian_cycle(num_vertices, directed_edges; fix_start=true, optimizer=nothing)

Build a JuMP model for Karp #9 (**Directed Hamilton Circuit**).
Uses binary position variables `x[v, pos]` with bijective assignment constraints and
non-arc transition exclusions `x[u, pos] + x[v, next_pos] <= 1`.
"""
function directed_hamiltonian_cycle(
    num_vertices::Integer,
    directed_edges::AbstractVector;
    fix_start::Bool = true,
    optimizer = nothing,
)
    n = Int(num_vertices)
    edges = _normalize_edges(n, directed_edges; directed = true)
    arc_set = Set(edges)

    model = _new_model(optimizer)
    JuMP.@variable(model, x[1:n, 1:n], Bin)

    if fix_start
        JuMP.@constraint(model, start_vertex, x[1, 1] == 1)
        for pos in 2:n
            JuMP.@constraint(model, x[1, pos] == 0)
        end
        for v in 2:n
            JuMP.@constraint(model, x[v, 1] == 0)
        end
        JuMP.@constraint(model, vertex_once[v in 2:n], sum(x[v, pos] for pos in 2:n) == 1)
        JuMP.@constraint(model, position_once[pos in 2:n], sum(x[v, pos] for v in 2:n) == 1)

        fixed_zero = Set{Tuple{Int, Int}}()
        for v in 2:n
            if !((1, v) in arc_set) && n >= 2
                JuMP.@constraint(model, x[v, 2] == 0)
                push!(fixed_zero, (v, 2))
            end
            if !((v, 1) in arc_set) && n >= 2
                JuMP.@constraint(model, x[v, n] == 0)
                push!(fixed_zero, (v, n))
            end
        end

        non_arcs = Tuple{Int, Int}[(u, v) for u in 2:n for v in 2:n if u != v && !((u, v) in arc_set)]
        for (u, v) in non_arcs, pos in 2:(n - 1)
            next_pos = pos + 1
            if !((u, pos) in fixed_zero) && !((v, next_pos) in fixed_zero)
                JuMP.@constraint(model, x[u, pos] + x[v, next_pos] <= 1)
            end
        end
    else
        JuMP.@constraint(model, vertex_once[v in 1:n], sum(x[v, pos] for pos in 1:n) == 1)
        JuMP.@constraint(model, position_once[pos in 1:n], sum(x[v, pos] for v in 1:n) == 1)

        non_arcs = Tuple{Int, Int}[(u, v) for u in 1:n for v in 1:n if u != v && !((u, v) in arc_set)]
        for (u, v) in non_arcs, pos in 1:n
            next_pos = mod1(pos + 1, n)
            JuMP.@constraint(model, x[u, pos] + x[v, next_pos] <= 1)
        end
    end

    JuMP.@objective(model, Min, 0.0)
    return model
end

"""
    Karp21.hamiltonian_cycle(num_vertices, edges; fix_start=true, optimizer=nothing)
    Karp21.hamiltonian_cycle(adj_matrix; fix_start=true, optimizer=nothing)

Build a JuMP model for Karp #10 (**Undirected Hamilton Circuit**).
"""
function hamiltonian_cycle(
    num_vertices::Integer,
    edges::AbstractVector;
    fix_start::Bool = true,
    optimizer = nothing,
)
    n = Int(num_vertices)
    undirected = _normalize_edges(n, edges; directed = false)
    directed = Tuple{Int, Int}[]
    for (u, v) in undirected
        push!(directed, (u, v))
        push!(directed, (v, u))
    end
    return directed_hamiltonian_cycle(n, directed; fix_start = fix_start, optimizer = optimizer)
end

function hamiltonian_cycle(
    adj::AbstractMatrix{<:Real};
    fix_start::Bool = true,
    optimizer = nothing,
)
    n, edges, _ = _edges_and_weights_from_matrix(adj; directed = false)
    return hamiltonian_cycle(n, edges; fix_start = fix_start, optimizer = optimizer)
end

"""
    Karp21.hamiltonian_path(num_vertices, edges; directed=false, start_vertex=nothing, end_vertex=nothing, optimizer=nothing)

Build a JuMP model for **Hamiltonian Path** (`pos in 1:n` without wrap-around transition `n -> 1`).
"""
function hamiltonian_path(
    num_vertices::Integer,
    edges::AbstractVector;
    directed::Bool = false,
    start_vertex::Union{Nothing, Integer} = nothing,
    end_vertex::Union{Nothing, Integer} = nothing,
    optimizer = nothing,
)
    n = Int(num_vertices)
    norm_edges = _normalize_edges(n, edges; directed = directed)
    arc_set = Set{Tuple{Int, Int}}()
    for (u, v) in norm_edges
        push!(arc_set, (u, v))
        if !directed
            push!(arc_set, (v, u))
        end
    end

    model = _new_model(optimizer)
    JuMP.@variable(model, x[1:n, 1:n], Bin)

    if !isnothing(start_vertex)
        JuMP.@constraint(model, fixed_start, x[Int(start_vertex), 1] == 1)
    end
    if !isnothing(end_vertex)
        JuMP.@constraint(model, fixed_end, x[Int(end_vertex), n] == 1)
    end

    JuMP.@constraint(model, vertex_once[v in 1:n], sum(x[v, pos] for pos in 1:n) == 1)
    JuMP.@constraint(model, position_once[pos in 1:n], sum(x[v, pos] for v in 1:n) == 1)

    non_arcs = Tuple{Int, Int}[(u, v) for u in 1:n for v in 1:n if u != v && !((u, v) in arc_set)]
    for (u, v) in non_arcs, pos in 1:(n - 1)
        JuMP.@constraint(model, x[u, pos] + x[v, pos + 1] <= 1)
    end

    JuMP.@objective(model, Min, 0.0)
    return model
end

"""
    Karp21.travelling_salesman(distance_matrix; fix_start=true, optimizer=nothing)

Build a JuMP model for the **Travelling Salesman Problem (TSP)** with quadratic tour-length
objective and bijective tour-position constraints.
"""
function travelling_salesman(
    distance_matrix::AbstractMatrix{<:Real};
    fix_start::Bool = true,
    optimizer = nothing,
)
    n, m = size(distance_matrix)
    n == m || throw(ArgumentError("distance_matrix must be square, got $(size(distance_matrix))"))
    n >= 2 || throw(ArgumentError("distance_matrix must have at least 2 vertices"))

    model = _new_model(optimizer)
    JuMP.@variable(model, x[1:n, 1:n], Bin)

    if fix_start
        JuMP.@constraint(model, start_vertex, x[1, 1] == 1)
    end

    JuMP.@constraint(model, vertex_once[v in 1:n], sum(x[v, pos] for pos in 1:n) == 1)
    JuMP.@constraint(model, position_once[pos in 1:n], sum(x[v, pos] for v in 1:n) == 1)

    JuMP.@objective(
        model,
        Min,
        sum(
            Float64(distance_matrix[u, v]) * x[u, pos] * x[v, mod1(pos + 1, n)]
            for u in 1:n for v in 1:n if u != v for pos in 1:n
        )
    )
    return model
end

"""
    Karp21.graph_coloring(num_vertices, edges, num_colors; minimize_colors=false, optimizer=nothing)
    Karp21.graph_coloring(adj_matrix, num_colors; minimize_colors=false, optimizer=nothing)

Build a JuMP model for Karp #12 (**Chromatic Number** / **Graph Coloring**).
Assigns each vertex `v` exactly one color `c in 1:num_colors` (`sum(x[v, :]) == 1`) and
forbids adjacent vertices from sharing a color (`x[u, c] + x[v, c] <= 1`).
When `minimize_colors=true`, introduces color-usage indicators `u[c]` and minimizes `sum(u)`.
"""
function graph_coloring(
    num_vertices::Integer,
    edges::AbstractVector,
    num_colors::Integer;
    minimize_colors::Bool = false,
    optimizer = nothing,
)
    n = Int(num_vertices)
    k = Int(num_colors)
    k >= 1 || throw(ArgumentError("num_colors must be at least 1"))
    norm_edges = _normalize_edges(n, edges; directed = false)

    model = _new_model(optimizer)
    JuMP.@variable(model, x[1:n, 1:k], Bin)
    JuMP.@constraint(model, one_color[v in 1:n], sum(x[v, c] for c in 1:k) == 1)

    if minimize_colors
        JuMP.@variable(model, u[1:k], Bin)
        covered_vertices = Set{Int}()
        for (i, j) in norm_edges
            push!(covered_vertices, i)
            push!(covered_vertices, j)
            for c in 1:k
                JuMP.@constraint(model, x[i, c] + x[j, c] <= u[c])
            end
        end
        for v in 1:n
            if !(v in covered_vertices)
                for c in 1:k
                    JuMP.@constraint(model, x[v, c] <= u[c])
                end
            end
        end
        JuMP.@objective(model, Min, sum(u))
    else
        for (i, j) in norm_edges, c in 1:k
            JuMP.@constraint(model, x[i, c] + x[j, c] <= 1)
        end
        JuMP.@objective(model, Min, 0.0)
    end

    return model
end

function graph_coloring(
    adj::AbstractMatrix{<:Real},
    num_colors::Integer;
    minimize_colors::Bool = false,
    optimizer = nothing,
)
    n, edges, _ = _edges_and_weights_from_matrix(adj; directed = false)
    return graph_coloring(n, edges, num_colors; minimize_colors = minimize_colors, optimizer = optimizer)
end

"""
    Karp21.chromatic_number(num_vertices, edges, max_colors; optimizer=nothing)
    Karp21.chromatic_number(adj_matrix, max_colors; optimizer=nothing)

Build a JuMP model for Karp #12 (**Chromatic Number**) minimizing the number of used colors.
"""
function chromatic_number(
    num_vertices::Integer,
    edges::AbstractVector,
    max_colors::Integer;
    optimizer = nothing,
)
    return graph_coloring(
        num_vertices,
        edges,
        max_colors;
        minimize_colors = true,
        optimizer = optimizer,
    )
end

function chromatic_number(
    adj::AbstractMatrix{<:Real},
    max_colors::Integer;
    optimizer = nothing,
)
    return graph_coloring(adj, max_colors; minimize_colors = true, optimizer = optimizer)
end

"""
    Karp21.clique_cover(num_vertices, edges, num_cliques; minimize_cliques=false, optimizer=nothing)
    Karp21.clique_cover(adj_matrix, num_cliques; minimize_cliques=false, optimizer=nothing)

Build a JuMP model for Karp #13 (**Clique Cover**), equivalent to coloring the complement graph.
"""
function clique_cover(
    num_vertices::Integer,
    edges::AbstractVector,
    num_cliques::Integer;
    minimize_cliques::Bool = false,
    optimizer = nothing,
)
    n = Int(num_vertices)
    norm_edges = _normalize_edges(n, edges; directed = false)
    edge_set = Set(norm_edges)
    complement_edges = Tuple{Int, Int}[
        (u, v) for u in 1:n for v in (u + 1):n if !((u, v) in edge_set)
    ]
    return graph_coloring(
        n,
        complement_edges,
        num_cliques;
        minimize_colors = minimize_cliques,
        optimizer = optimizer,
    )
end

function clique_cover(
    adj::AbstractMatrix{<:Real},
    num_cliques::Integer;
    minimize_cliques::Bool = false,
    optimizer = nothing,
)
    n, edges, _ = _edges_and_weights_from_matrix(adj; directed = false)
    return clique_cover(n, edges, num_cliques; minimize_cliques = minimize_cliques, optimizer = optimizer)
end

"""
    Karp21.exact_cover(universe, subsets; weights=nothing, optimizer=nothing)

Build a JuMP model for Karp #14 (**Exact Cover**).
Registers exact partitioning constraints `sum(x[j] for j with e in subsets[j]) == 1`
for every `e in universe`.
"""
function exact_cover(
    universe::AbstractVector,
    subsets::AbstractVector{<:AbstractVector};
    weights::Union{Nothing, AbstractVector{<:Real}} = nothing,
    optimizer = nothing,
)
    m = length(subsets)
    m >= 1 || throw(ArgumentError("subsets must not be empty"))
    w = isnothing(weights) ? zeros(Float64, m) : _default_weights(m, weights)
    subset_sets = [Set(s) for s in subsets]

    for e in universe
        any(e in s for s in subset_sets) ||
            throw(ArgumentError("universe element $(repr(e)) is not present in any subset"))
    end

    model = _new_model(optimizer)
    JuMP.@variable(model, x[1:m], Bin)
    JuMP.@constraint(
        model,
        exact_elem[i in eachindex(universe)],
        sum(x[j] for j in 1:m if universe[i] in subset_sets[j]) == 1
    )
    JuMP.@objective(model, Min, sum(w[j] * x[j] for j in 1:m))
    return model
end

"""
    Karp21.hitting_set(universe, subsets; weights=nothing, optimizer=nothing)

Build a JuMP model for Karp #15 (**Hitting Set**).
Selects elements `x[i]` from `universe` so every subset in `subsets` contains at least one
selected element (`sum(x[i] for u[i] in S_j) >= 1`), minimizing `sum(weights[i] * x[i])`.
"""
function hitting_set(
    universe::AbstractVector,
    subsets::AbstractVector{<:AbstractVector};
    weights::Union{Nothing, AbstractVector{<:Real}} = nothing,
    optimizer = nothing,
)
    n = length(universe)
    n >= 1 || throw(ArgumentError("universe must not be empty"))
    isempty(subsets) && throw(ArgumentError("subsets must not be empty"))
    w = _default_weights(n, weights)
    elem_index = Dict(universe[i] => i for i in 1:n)

    subset_indices = Vector{Vector{Int}}(undef, length(subsets))
    for (j, s) in enumerate(subsets)
        isempty(s) && throw(ArgumentError("subset $(j) must not be empty"))
        idxs = Int[]
        for elem in s
            haskey(elem_index, elem) ||
                throw(ArgumentError("subset $(j) element $(repr(elem)) is not in universe"))
            push!(idxs, elem_index[elem])
        end
        subset_indices[j] = unique(idxs)
    end

    model = _new_model(optimizer)
    JuMP.@variable(model, x[1:n], Bin)
    JuMP.@constraint(
        model,
        hit_subset[j in eachindex(subset_indices)],
        sum(x[i] for i in subset_indices[j]) >= 1
    )
    JuMP.@objective(model, Min, sum(w[i] * x[i] for i in 1:n))
    return model
end

"""
    Karp21.steiner_tree(num_vertices, edges, terminals; weights=nothing, optimizer=nothing)

Build a JuMP model for Karp #16 (**Steiner Tree**).
Selects vertex indicators `x[v]` (`x[t] == 1` for `t in terminals`) and edge indicators
`y[e]` (`1:m`) satisfying tree cardinality `sum(y) == sum(x) - 1`, endpoint inclusion
`y[e] <= x[u]` and `y[e] <= x[v]`, and terminal-cut connectivity constraints.
"""
function steiner_tree(
    num_vertices::Integer,
    edges::AbstractVector,
    terminals::AbstractVector{<:Integer};
    weights::Union{Nothing, AbstractVector{<:Real}} = nothing,
    optimizer = nothing,
)
    n = Int(num_vertices)
    norm_edges = _normalize_edges(n, edges; directed = false)
    m = length(norm_edges)
    m >= 1 || throw(ArgumentError("edges must not be empty"))
    w = _default_weights(m, weights)

    term_set = unique(Int.(terminals))
    isempty(term_set) && throw(ArgumentError("terminals must not be empty"))
    all(t -> 1 <= t <= n, term_set) ||
        throw(ArgumentError("all terminals must be in 1:$(n)"))

    model = _new_model(optimizer)
    JuMP.@variable(model, x[1:n], Bin)
    JuMP.@variable(model, y[1:m], Bin)

    term_lookup = Set(term_set)
    for t in term_set
        JuMP.@constraint(model, x[t] == 1)
    end

    for (e_idx, (u, v)) in enumerate(norm_edges)
        !(u in term_lookup) && JuMP.@constraint(model, y[e_idx] <= x[u])
        !(v in term_lookup) && JuMP.@constraint(model, y[e_idx] <= x[v])
    end

    JuMP.@constraint(model, tree_size, sum(y) == sum(x) - 1)

    if length(term_set) >= 2 && n <= 10
        root = first(term_set)
        other_terminals = setdiff(term_set, [root])
        non_root_vertices = [v for v in 1:n if v != root]
        num_non_root = length(non_root_vertices)
        candidate_cuts = Vector{Int}[]
        seen_cuts = Set{Vector{Int}}()
        for mask in 0:((1 << num_non_root) - 1)
            S = Set{Int}([root])
            for bit in 1:num_non_root
                if ((mask >> (bit - 1)) & 1) == 1
                    push!(S, non_root_vertices[bit])
                end
            end
            if any(t -> !(t in S), other_terminals)
                cut_edges = Int[
                    e_idx for (e_idx, (u, v)) in enumerate(norm_edges)
                    if (u in S) != (v in S)
                ]
                isempty(cut_edges) &&
                    throw(ArgumentError("graph does not connect all terminals"))
                if !(cut_edges in seen_cuts)
                    push!(seen_cuts, cut_edges)
                    push!(candidate_cuts, cut_edges)
                end
            end
        end
        sort!(candidate_cuts; by = length)
        minimal_cuts = Vector{Int}[]
        for cut in candidate_cuts
            cut_set = Set(cut)
            if !any(prev -> issubset(prev, cut_set), minimal_cuts)
                push!(minimal_cuts, cut)
                if length(cut) == 1
                    JuMP.@constraint(model, y[only(cut)] == 1)
                else
                    JuMP.@constraint(model, sum(y[e_idx] for e_idx in cut) >= 1)
                end
            end
        end
    end

    JuMP.@objective(model, Min, sum(w[e_idx] * y[e_idx] for e_idx in 1:m))
    return model
end

"""
    Karp21.three_dimensional_matching(triples; num_x=nothing, num_y=nothing, num_z=nothing, weights=nothing, target_size=nothing, optimizer=nothing)

Build a JuMP model for Karp #17 (**3-Dimensional Matching**).
Given candidate triples `(x_i, y_j, z_k)`, selects a pairwise disjoint subset of triples
maximizing `sum(weights[t] * m[t])`.
"""
function three_dimensional_matching(
    triples::AbstractVector;
    num_x::Union{Nothing, Integer} = nothing,
    num_y::Union{Nothing, Integer} = nothing,
    num_z::Union{Nothing, Integer} = nothing,
    weights::Union{Nothing, AbstractVector{<:Real}} = nothing,
    target_size::Union{Nothing, Integer} = nothing,
    optimizer = nothing,
)
    t_count = length(triples)
    t_count >= 1 || throw(ArgumentError("triples must not be empty"))
    parsed = Tuple{Int, Int, Int}[]
    for t in triples
        length(t) == 3 || throw(ArgumentError("each triple must have 3 elements, got $(repr(t))"))
        push!(parsed, (Int(t[1]), Int(t[2]), Int(t[3])))
    end

    nx = isnothing(num_x) ? maximum(t[1] for t in parsed) : Int(num_x)
    ny = isnothing(num_y) ? maximum(t[2] for t in parsed) : Int(num_y)
    nz = isnothing(num_z) ? maximum(t[3] for t in parsed) : Int(num_z)
    w = _default_weights(t_count, weights)

    model = _new_model(optimizer)
    JuMP.@variable(model, m[1:t_count], Bin)

    for i in 1:nx
        idxs = [t for t in 1:t_count if parsed[t][1] == i]
        length(idxs) >= 2 && JuMP.@constraint(model, sum(m[t] for t in idxs) <= 1)
    end
    for j in 1:ny
        idxs = [t for t in 1:t_count if parsed[t][2] == j]
        length(idxs) >= 2 && JuMP.@constraint(model, sum(m[t] for t in idxs) <= 1)
    end
    for k in 1:nz
        idxs = [t for t in 1:t_count if parsed[t][3] == k]
        length(idxs) >= 2 && JuMP.@constraint(model, sum(m[t] for t in idxs) <= 1)
    end

    if !isnothing(target_size)
        JuMP.@constraint(model, matching_size, sum(m) == Int(target_size))
    end

    JuMP.@objective(model, Max, sum(w[t] * m[t] for t in 1:t_count))
    return model
end

const three_d_matching = three_dimensional_matching

"""
    Karp21.knapsack(weights, values, capacity; optimizer=nothing)

Build a JuMP model for Karp #18 (**0-1 Knapsack**).
Maximizes `sum(values[i] * x[i])` subject to `sum(weights[i] * x[i]) <= capacity`.
"""
function knapsack(
    weights::AbstractVector{<:Real},
    values::AbstractVector{<:Real},
    capacity::Real;
    optimizer = nothing,
)
    n = length(weights)
    n >= 1 || throw(ArgumentError("weights must not be empty"))
    length(values) == n || throw(ArgumentError("values length ($(length(values))) must match weights length ($(n))"))
    capacity >= 0 || throw(ArgumentError("capacity must be non-negative"))

    model = _new_model(optimizer)
    JuMP.@variable(model, x[1:n], Bin)
    JuMP.@constraint(model, capacity_limit, sum(weights[i] * x[i] for i in 1:n) <= capacity)
    JuMP.@objective(model, Max, sum(values[i] * x[i] for i in 1:n))
    return model
end

"""
    Karp21.subset_sum(numbers, target; optimizer=nothing)

Build a JuMP model for Karp #18 (**Subset Sum**): `sum(numbers[i] * x[i]) == target`.
"""
function subset_sum(
    numbers::AbstractVector{<:Real},
    target::Real;
    optimizer = nothing,
)
    n = length(numbers)
    n >= 1 || throw(ArgumentError("numbers must not be empty"))

    model = _new_model(optimizer)
    JuMP.@variable(model, x[1:n], Bin)
    JuMP.@constraint(model, target_sum, sum(numbers[i] * x[i] for i in 1:n) == target)
    JuMP.@objective(model, Min, 0.0)
    return model
end

"""
    Karp21.job_sequencing(execution_times, deadlines, penalties; optimizer=nothing)

Build a JuMP model for Karp #19 (**Job Sequencing**).
Schedules `n` jobs across `n` sequential slots via binary assignment variables `x[i, k]`
and tardiness indicators `u[i]`, minimizing total tardiness penalty `sum(penalties[i] * u[i])`.
"""
function job_sequencing(
    execution_times::AbstractVector{<:Real},
    deadlines::AbstractVector{<:Real},
    penalties::AbstractVector{<:Real};
    optimizer = nothing,
)
    n = length(execution_times)
    n >= 1 || throw(ArgumentError("execution_times must not be empty"))
    length(deadlines) == n || throw(ArgumentError("deadlines length must match execution_times length"))
    length(penalties) == n || throw(ArgumentError("penalties length must match execution_times length"))
    all(t -> t > 0, execution_times) || throw(ArgumentError("execution_times must be positive"))
    all(d -> d >= 0, deadlines) || throw(ArgumentError("deadlines must be non-negative"))
    all(p -> p >= 0, penalties) || throw(ArgumentError("penalties must be non-negative"))

    model = _new_model(optimizer)
    JuMP.@variable(model, x[1:n, 1:n], Bin)
    JuMP.@variable(model, u[1:n], Bin)

    JuMP.@constraint(model, job_once[i in 1:n], sum(x[i, k] for k in 1:n) == 1)
    JuMP.@constraint(model, slot_once[k in 1:n], sum(x[i, k] for i in 1:n) == 1)

    for i in 1:n
        other_times = sort(Float64[Float64(execution_times[j]) for j in 1:n if j != i]; rev = true)
        for k in 1:n
            max_before = sum(other_times[1:min(k - 1, length(other_times))]; init = 0.0)
            max_completion_ik = Float64(execution_times[i]) + max_before
            big_m = max_completion_ik - Float64(deadlines[i])
            if big_m > 0.0
                JuMP.@constraint(
                    model,
                    sum(Float64(execution_times[j]) * x[j, r] for j in 1:n if j != i for r in 1:(k - 1)) +
                    Float64(execution_times[i]) * x[i, k] -
                    big_m * (1 - x[i, k]) -
                    big_m * u[i] <= Float64(deadlines[i])
                )
            end
        end
    end

    JuMP.@objective(model, Min, sum(Float64(penalties[i]) * u[i] for i in 1:n))
    return model
end

"""
    Karp21.number_partition(numbers; exact=true, optimizer=nothing)

Build a JuMP model for Karp #20 (**Partition** / **Number Partitioning**).
When `exact=true` (default), registers the exact partition equality constraint
`2 * sum(numbers[i] * x[i]) == sum(numbers)` (fixing `x[1] == 1` to break symmetry).
When `exact=false`, minimizes the squared discrepancy `(sum(numbers[i] * (2x[i] - 1)))^2`.
"""
function number_partition(
    numbers::AbstractVector{<:Real};
    exact::Bool = true,
    fix_first::Bool = true,
    optimizer = nothing,
)
    n = length(numbers)
    n >= 1 || throw(ArgumentError("numbers must not be empty"))
    total = sum(numbers)

    model = _new_model(optimizer)
    JuMP.@variable(model, x[1:n], Bin)
    if fix_first
        JuMP.@constraint(model, symmetry_break, x[1] == 1)
    end

    if exact
        JuMP.@constraint(model, partition_balance, 2 * sum(numbers[i] * x[i] for i in 1:n) == total)
        JuMP.@objective(model, Min, 0.0)
    else
        JuMP.@objective(model, Min, (sum(Float64(numbers[i]) * (2 * x[i] - 1) for i in 1:n))^2)
    end

    return model
end

"""
    Karp21.max_cut(num_vertices, edges; weights=nothing, fix_first=true, optimizer=nothing)
    Karp21.max_cut(adj_matrix; fix_first=true, optimizer=nothing)

Build a JuMP model for Karp #21 (**Max-Cut**).
Maximizes the weighted cut value `sum(w[e] * (x[u] + x[v] - 2 * x[u] * x[v]))` with optional
symmetry-breaking constraint `x[1] == 0`.
"""
function max_cut(
    num_vertices::Integer,
    edges::AbstractVector;
    weights::Union{Nothing, AbstractVector{<:Real}} = nothing,
    fix_first::Bool = true,
    optimizer = nothing,
)
    n = Int(num_vertices)
    norm_edges = _normalize_edges(n, edges; directed = false)
    w = _default_weights(length(norm_edges), weights)

    model = _new_model(optimizer)
    JuMP.@variable(model, x[1:n], Bin)
    if fix_first
        JuMP.@constraint(model, symmetry_break, x[1] == 0)
    end
    JuMP.@objective(
        model,
        Max,
        sum(
            w[idx] * (x[u] + x[v] - 2 * x[u] * x[v])
            for (idx, (u, v)) in enumerate(norm_edges)
        )
    )
    return model
end

function max_cut(
    adj::AbstractMatrix{<:Real};
    fix_first::Bool = true,
    optimizer = nothing,
)
    n, edges, weights = _edges_and_weights_from_matrix(adj; directed = false)
    return max_cut(n, edges; weights = weights, fix_first = fix_first, optimizer = optimizer)
end

"""
    Karp21.PROBLEMS

Catalog of all 21 NP-complete problems from Karp (1972), *"Reducibility Among Combinatorial
Problems"*, mapped to their JuMP model builders in `QUBO.Karp21`.
"""
const PROBLEMS = [
    (karp_index = 1,  name = :satisfiability,               family = :logic,  builder = satisfiability,               description = "Satisfiability (CNF-SAT / Max-SAT)"),
    (karp_index = 2,  name = :zero_one_integer_programming, family = :number, builder = zero_one_integer_programming, description = "0-1 Integer Programming"),
    (karp_index = 3,  name = :clique,                       family = :graph,  builder = clique,                       description = "Maximum Clique"),
    (karp_index = 4,  name = :set_packing,                  family = :set,    builder = set_packing,                  description = "Set Packing"),
    (karp_index = 5,  name = :vertex_cover,                 family = :graph,  builder = vertex_cover,                 description = "Minimum Vertex Cover (Node Cover)"),
    (karp_index = 6,  name = :set_cover,                    family = :set,    builder = set_cover,                    description = "Minimum Set Covering"),
    (karp_index = 7,  name = :feedback_vertex_set,          family = :graph,  builder = feedback_vertex_set,          description = "Directed Feedback Vertex Set (Feedback Node Set)"),
    (karp_index = 8,  name = :feedback_arc_set,             family = :graph,  builder = feedback_arc_set,             description = "Directed Feedback Arc Set"),
    (karp_index = 9,  name = :directed_hamiltonian_cycle,   family = :graph,  builder = directed_hamiltonian_cycle,   description = "Directed Hamiltonian Circuit"),
    (karp_index = 10, name = :hamiltonian_cycle,            family = :graph,  builder = hamiltonian_cycle,            description = "Undirected Hamiltonian Circuit"),
    (karp_index = 11, name = :three_sat,                    family = :logic,  builder = three_sat,                    description = "3-Satisfiability (3-SAT)"),
    (karp_index = 12, name = :chromatic_number,             family = :graph,  builder = chromatic_number,             description = "Chromatic Number / Graph Coloring"),
    (karp_index = 13, name = :clique_cover,                 family = :graph,  builder = clique_cover,                 description = "Clique Cover"),
    (karp_index = 14, name = :exact_cover,                  family = :set,    builder = exact_cover,                  description = "Exact Cover"),
    (karp_index = 15, name = :hitting_set,                  family = :set,    builder = hitting_set,                  description = "Minimum Hitting Set"),
    (karp_index = 16, name = :steiner_tree,                 family = :graph,  builder = steiner_tree,                 description = "Steiner Tree in Graphs"),
    (karp_index = 17, name = :three_dimensional_matching,   family = :set,    builder = three_dimensional_matching,   description = "3-Dimensional Matching"),
    (karp_index = 18, name = :knapsack,                     family = :number, builder = knapsack,                     description = "0-1 Knapsack / Subset Sum"),
    (karp_index = 19, name = :job_sequencing,               family = :number, builder = job_sequencing,               description = "Job Sequencing with Deadlines and Penalties"),
    (karp_index = 20, name = :number_partition,             family = :number, builder = number_partition,             description = "Number Partition"),
    (karp_index = 21, name = :max_cut,                      family = :graph,  builder = max_cut,                      description = "Maximum Cut (Max-Cut)"),
]

end # module Karp21

