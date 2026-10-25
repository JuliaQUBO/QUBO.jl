# Karp-21 Problem Library

`QUBO.Karp21` provides ready-to-use, JuMP-native model builders for all 21
NP-complete problems from Richard M. Karp's 1972 paper *"Reducibility Among
Combinatorial Problems"* (plus standard optimization variants such as
`independent_set`, `hamiltonian_path`, `travelling_salesman`, and `subset_sum`).

Rather than hard-coding manual penalty coefficients, every builder returns a
constrained `JuMP.Model` whose constraints are automatically compiled and
penalized by [`ToQUBO.jl`](https://github.com/JuliaQUBO/ToQUBO.jl) and whose
post-solve constraint satisfaction can be audited with
`ToQUBO.feasibility_report(model)`.

## Problem Catalog

`Karp21.PROBLEMS` lists all 21 Karp problems in their original 1972 numbering:

```@example karp21
using JuMP
using QUBO

[(p.karp_index, p.name, p.family, p.description) for p in Karp21.PROBLEMS]
```

| # | Karp Problem | `QUBO.Karp21` Builder | Family |
|---|--------------|-----------------------|--------|
| 1 | Satisfiability | `Karp21.satisfiability` / `Karp21.sat` | `:logic` |
| 2 | 0-1 Integer Programming | `Karp21.zero_one_integer_programming` | `:number` |
| 3 | Clique | `Karp21.clique` (and `Karp21.independent_set`) | `:graph` |
| 4 | Set Packing | `Karp21.set_packing` | `:set` |
| 5 | Node Cover (Vertex Cover) | `Karp21.vertex_cover` | `:graph` |
| 6 | Set Covering | `Karp21.set_cover` | `:set` |
| 7 | Feedback Node Set | `Karp21.feedback_vertex_set` | `:graph` |
| 8 | Feedback Arc Set | `Karp21.feedback_arc_set` | `:graph` |
| 9 | Directed Hamilton Circuit | `Karp21.directed_hamiltonian_cycle` | `:graph` |
| 10 | Undirected Hamilton Circuit | `Karp21.hamiltonian_cycle` (`hamiltonian_path`, `travelling_salesman`) | `:graph` |
| 11 | 3-Satisfiability (3-SAT) | `Karp21.three_sat` | `:logic` |
| 12 | Chromatic Number | `Karp21.chromatic_number` / `Karp21.graph_coloring` | `:graph` |
| 13 | Clique Cover | `Karp21.clique_cover` | `:graph` |
| 14 | Exact Cover | `Karp21.exact_cover` | `:set` |
| 15 | Hitting Set | `Karp21.hitting_set` | `:set` |
| 16 | Steiner Tree | `Karp21.steiner_tree` | `:graph` |
| 17 | 3-Dimensional Matching | `Karp21.three_dimensional_matching` | `:set` |
| 18 | Knapsack / Subset Sum | `Karp21.knapsack` / `Karp21.subset_sum` | `:number` |
| 19 | Job Sequencing | `Karp21.job_sequencing` | `:number` |
| 20 | Partition | `Karp21.number_partition` | `:number` |
| 21 | Max-Cut | `Karp21.max_cut` | `:graph` |

## Example: Maximum Clique & Feasibility Audit

```@example karp21
edges = [(1, 2), (2, 3), (1, 3), (3, 4)]
model = Karp21.clique(
    4,
    edges;
    optimizer = () -> ToQUBO.Optimizer(ExactSampler.Optimizer),
)
optimize!(model)

rep = ToQUBO.feasibility_report(model)
(
    selected = round.(Int, value.(model[:x])),
    objective = objective_value(model),
    feasible = rep.results[1].feasible,
)
```

## API Reference

```@docs
Karp21.PROBLEMS
Karp21.satisfiability
Karp21.three_sat
Karp21.zero_one_integer_programming
Karp21.clique
Karp21.independent_set
Karp21.set_packing
Karp21.vertex_cover
Karp21.set_cover
Karp21.feedback_vertex_set
Karp21.feedback_arc_set
Karp21.directed_hamiltonian_cycle
Karp21.hamiltonian_cycle
Karp21.hamiltonian_path
Karp21.travelling_salesman
Karp21.graph_coloring
Karp21.chromatic_number
Karp21.clique_cover
Karp21.exact_cover
Karp21.hitting_set
Karp21.steiner_tree
Karp21.three_dimensional_matching
Karp21.knapsack
Karp21.subset_sum
Karp21.job_sequencing
Karp21.number_partition
Karp21.max_cut
```

