# Design & Architecture

QUBO.jl is the entrypoint package for the JuliaQUBO ecosystem. The package code
is intentionally thin: it imports and re-exports the compiler, sampler, and
tooling packages, then adds small JuMP and QUBOTools integrations for common
workflows.

The architecture below follows the package boundaries in the current source
code. The QUBO.jl paper provides useful background, but the code is the source
of truth for this diagram.

```@raw html
<pre class="mermaid">
flowchart TB
    user["User code&lt;br/&gt;using QUBO&lt;br/&gt;JuMP.Model"]

    subgraph qubo["QUBO.jl entrypoint package"]
        direction LR
        reexports["Imports and re-exports&lt;br/&gt;ToQUBO.jl / QUBODrivers.jl&lt;br/&gt;/ QUBOTools.jl"]
        integrations["Local integrations&lt;br/&gt;Spin, NumberOfReads,&lt;br/&gt;reads(model)&lt;br/&gt;source_model / target_model&lt;br/&gt;QUBOTools.backend(::JuMP.Model)"]
    end

    subgraph toqubo["ToQUBO.jl compiler"]
        direction TB
        source["source_model&lt;br/&gt;PreQUBO / MOI"]
        ir["PBO/PBF compiler state&lt;br/&gt;encodings + penalties&lt;br/&gt;quadratization when needed"]
        target["target_model&lt;br/&gt;QUBOTools_MOI.QUBOModel&lt;br/&gt;binary quadratic MOI model"]
    end

    subgraph drivers["QUBODrivers.jl sampler layer"]
        direction TB
        samplers["MOI sampler optimizers&lt;br/&gt;Exact / Random / Identity / others"]
        resultattrs["MOI result attributes&lt;br/&gt;objective values / primals&lt;br/&gt;/ reads"]
    end

    subgraph tools["QUBOTools.jl model and analysis layer"]
        direction TB
        qmodel["QUBOTools.Model&lt;br/&gt;QUBO / Ising forms"]
        solution["Sample / SampleSet&lt;br/&gt;solution data"]
        files["read/write model and solution files"]
        analysis["metrics and plotting recipes"]
    end

    user --> reexports --> source
    integrations -.-> qmodel

    source --> ir --> target
    target --> samplers --> resultattrs --> solution
    target -.->|"backend"| qmodel
    qmodel --> files
    solution --> files
    qmodel --> analysis
    solution --> analysis
</pre>
```

## Ecosystem Layers

`QUBO.jl` is the entrypoint layer. Its source imports and exports
`ToQUBO.jl`, `QUBODrivers.jl`, and `QUBOTools.jl`, exports the built-in
samplers from QUBODrivers, and exposes QUBOTools' `Spin`, `NumberOfReads`, and
`reads` APIs. It also defines the JuMP-facing convenience functions
`source_model`, `target_model`, and `QUBOTools.backend(::JuMP.Model)`.

`ToQUBO.jl` is the compiler layer. Its optimizer is a virtual MOI optimizer
with a `source_model`, a `target_model`, and compiler state for variables,
constraints, pseudo-Boolean functions, penalties, and the final compiled
objective. During `MOI.optimize!`, ToQUBO compiles the source model and writes a
binary quadratic target model.

`QUBODrivers.jl` is the sampler layer. Sampler optimizers subtype an MOI
optimizer abstraction, accept QUBO or Ising models, store a `QUBOTools.Model`,
and expose results through MOI attributes. Built-in samplers such as
`ExactSampler`, `RandomSampler`, and `IdentitySampler` are re-exported by
QUBO.jl.

`QUBOTools.jl` is the model, solution, file I/O, and analysis layer. It defines
the model and solution abstractions used by the compiler and samplers, handles
QUBO and Ising forms, reads and writes model and solution files, and backs
analysis utilities such as density metrics and plotting recipes.

## Compilation Through PBO

PBO is part of the ToQUBO.jl compiler internals, not a separate implementation
inside the QUBO.jl entrypoint package. The ToQUBO source imports
`PseudoBooleanOptimization` as `PBO` and stores pseudo-Boolean function state in
the virtual model while compiling the source MOI model into a binary quadratic
target model.

After the original JuMP/MOI model is available, ToQUBO.jl applies variable
encoding and constraint penalization so the problem can be represented over
binary variables.

The intermediate mathematical representation is a pseudo-Boolean function
(Boros and Hammer, 2002): a real polynomial over binary variables,

```math
f(x) = \sum_{\omega \in \mathcal{P}([n])} c_{\omega}
       \prod_{j \in \omega} x_j,
```

where ``x \in \{0, 1\}^n``. This representation is natural for ToQUBO's
compiler because optimizing a degree-two pseudo-Boolean function over binary
variables is equivalent to optimizing a QUBO, up to the constant term.

Some constraint mappings produce higher-degree pseudo-Boolean terms. Those terms
must be quadratized before they can be written to the binary quadratic target
model. In the current ToQUBO code, compiler routines set a `Quadratize` flag
when they generate high-order pseudo-Boolean terms, then the build step calls
`PBO.quadratize!` before writing the target MOI objective. The paper cites
Dattani for a survey of quadratization methods and Boros-Gruber for
positive-term quadratization.

In summary, the compilation path is:

```text
JuMP/MOI model
  -> variable encoding and constraint penalization
  -> ToQUBO pseudo-Boolean compiler state
  -> quadratization when high-order terms are generated
  -> binary quadratic MOI target model
```

## [Standalone Decomposition: Accepted Design and Implementation](@id Standalone-Decomposition:-First-Design-Slice)

The standalone architecture accepted in
[epic #73](https://github.com/JuliaQUBO/QUBO.jl/issues/73) is implemented in
[JuliaQUBO/QUBODecomposition.jl](https://github.com/JuliaQUBO/QUBODecomposition.jl).
The original QUBO.jl issue #74 was transferred with its history to the
[implementation tracker](https://github.com/JuliaQUBO/QUBODecomposition.jl/issues/1).
The contracts below preserve the accepted design; the
[package manual](https://juliaqubo.github.io/QUBO.jl/QUBODecomposition.jl/dev/)
is authoritative for current configuration, algorithms, results and usage.
These APIs belong to the standalone package and are not re-exported by QUBO.

Whole-model dispatch, disconnected components, conditioned serial sweeps,
complete-state reconstruction and original-energy evaluation are implemented.
The package's [acceptance matrix](https://juliaqubo.github.io/QUBO.jl/QUBODecomposition.jl/dev/acceptance/)
records delivered rows 1–20, including driver conformance, direct JuMP and
released ToQUBO 0.7.1 composition/repeated compilation. Coupled sweeps remain
heuristic: exact neighborhoods do not prove a coupled global optimum.
Release/fresh-install row 21, registration and ecosystem adoption remain
separate gates; the package is still unregistered and unreleased.

### Destination, Ownership, and Dependencies

The established repository is **JuliaQUBO/QUBODecomposition.jl**, with Julia
package/module `QUBODecomposition` and `QUBODecomposition.Optimizer`.
[@bernalde](https://github.com/bernalde) is the accepted maintainer and release
authority, responsible for sampler correctness, release/access continuity,
dependency updates and downstream integration CI. General registration is the
accepted first-release route; a project version of 0.1.0 does not establish
that a tag, release or registry installation exists.

| Responsibility | Owning implementation/test location |
| :-- | :-- |
| Plans, neighborhoods, incumbents, budgets, child execution, seed derivation, candidate accounting and result statuses | Standalone package `src/`; its `test/unit/` |
| Forms, labels, fixing/lifting and graph export | Existing QUBOTools public interfaces; generic regressions stay upstream |
| Sampler interface and conformance | Existing QUBODrivers/MOI interfaces; standalone `test/conformance.jl`; coordination in [QUBODrivers#87](https://github.com/JuliaQUBO/QUBODrivers.jl/issues/87) |
| ToQUBO composition, decoding, source feasibility and penalty-refinement integration | Standalone `test/integration/toqubo.jl`; coordination in [ToQUBO#244](https://github.com/JuliaQUBO/ToQUBO.jl/issues/244) |
| Entrypoint discovery and eventual ecosystem canary | QUBO.jl docs/canary under #73; no automatic re-export or dependency |

The production dependencies are QUBOTools, QUBODrivers and MathOptInterface,
plus only used Julia standard libraries. Use a small local adjacency traversal
from public quadratic terms for the first serial implementation; a direct
Graphs dependency is needed only if its API is actually called. JuMP, ToQUBO
and `Test` belong in the standalone test/example environments. Python, QSplit,
D-Wave Hybrid, external services and a concrete solver are not production
requirements. The user supplies the child optimizer.

The supported runtime floor is Julia 1.10, QUBOTools **0.16.2**,
QUBODrivers **0.6.5**, and MathOptInterface **1**. JuMP **1** and released
ToQUBO **0.7.1** are test/example dependencies; they do not broaden QUBO's
runtime dependencies or ToQUBO compatibility. The package CI tests the runtime
floor with MOI 1.0.0 and all driver-conformance groups; direct JuMP runs in the
compatible integration environments (JuMP 1 requires MOI >=1.1.1).

QUBOTools 0.16.2 is [released](https://github.com/JuliaQUBO/QUBOTools.jl/releases/tag/v0.16.2)
and [registered](https://github.com/JuliaRegistries/General/pull/170908), preserving
isolates in graph exports. [Conditioning PR #139](https://github.com/JuliaQUBO/QUBOTools.jl/pull/139)
added documentation/tests without a new runtime API or release prerequisite.
Registered QUBODrivers 0.6.5 supplies the public seed, metadata, timing/read traits
and conformance entry point.

**Released integration prerequisite:** ToQUBO
[0.7.1](https://github.com/JuliaQUBO/ToQUBO.jl/releases/tag/v0.7.1) includes public
`MaxPenaltyUpdates`, `PrimalFeasibilityCheck` and the ordinary-recompilation fix.
The downstream test/example minimum and pinned integration CI lane now require
0.7.1, with passing ordinary repeated-solve and source-feasibility evidence.
This supersedes the historical 0.6.1 baseline and unreleased-source prerequisite;
[ToQUBO#244](https://github.com/JuliaQUBO/ToQUBO.jl/issues/244) records the release
and downstream coordination. No upstream development override is required.

### [Public Interface and Existing Building Blocks](@id Proposed-Public-Interface-and-Existing-Building-Blocks)

Construction accepts one zero-argument child factory returning a fresh, empty
MOI optimizer per child call. It must not return a shared live optimizer.
Attributes configured by that factory are retained except for the explicit
per-call seed and remaining time limit. The first coefficient type is `Float64`;
reject non-finite coefficients, scale, offset and evaluated energies. Preserve
finite scale, including zero and negative scale, by evaluating the complete
scaled objective and retaining the original sense.

The accepted construction below matches the standalone public interface.
It requires a separately installed development checkout; the package manual
contains executable examples and the detailed configuration contract:

```julia
using JuMP, QUBODrivers, ToQUBO, QUBODecomposition

child = () -> QUBODrivers.ExactSampler.Optimizer()
composite = () -> QUBODecomposition.Optimizer(;
    child_optimizer = child,
    max_variables = 8,
    strategy = :components_then_sweeps,
    max_sweeps = 20,
    max_child_calls = 1_000,
    max_candidate_evaluations = 100_000,
    stagnation_sweeps = 2,
    child_time_limit_sec = nothing,
    seed = 123,
)
model = Model(composite)                         # unconstrained binary/spin QP
compiled_model = Model(() -> ToQUBO.Optimizer(composite)) # source constraints
```

`Optimizer()` must also exist for driver conformance and allow configuration
before `optimize!`; `child_optimizer` and `max_variables` are required before
solving. Keyword names above also name raw optimizer attributes.
Unknown attributes fail explicitly. `max_variables` is a positive integer
(excluding `Bool`), even for an empty model. Other work limits are nonnegative
integers excluding `Bool`; `stagnation_sweeps` is positive. Time limits are
`nothing` or finite nonnegative seconds. The optional seed is a nonnegative
integer in `0:2^31-2`; `nothing` means no child seed is imposed. Invalid
configuration fails before any child call and clears prior solve results.
Support `MOI.TimeLimitSec()` for one composite invocation and
`QUBODrivers.RandomSeed()` through the public `"seed"` attribute.

The original design proposed `QUBODrivers.@setup`; the implementation uses it
for internal model storage and defines the composite optimizer explicitly.
Both use the public driver interfaces. Implement `QUBODrivers.sample`, reading the model
through `QUBOTools.backend`. Return a `QUBOTools.SampleSet` in the original
frame. `QUBODrivers.set_model!` and `MOI.copy_to` are existing public model
hooks. Implement an optimizer-specific `MOI.get(..., MOI.TerminationStatus())`
method for the status semantics below; retain the shared
`MOI.SolveTimeSec()` timing convention. Do not call private `_sample!` or
`_sampler_metadata`: construct the documented metadata dictionary and call
`validate_metadata` in tests.

For each child, build a temporary MOI model using public `MOI.Utilities` model
storage, domain constraints and `ScalarQuadraticFunction`, then `MOI.copy_to`
into the factory result. Keep the returned MOI index map. The reduced expression
``\alpha(\beta + \sum_i l_i x_i + \sum_{i<j}q_{ij}x_ix_j)`` becomes constant
``\alpha\beta``, affine coefficients ``\alpha l_i`` and off-diagonal quadratic
coefficients ``\alpha q_{ij}``; if a diagonal MOI term is used its coefficient
is twice the polynomial coefficient. No private compiler conversion is needed.
Create every variable explicitly, including zero columns. Read child primals
through the copied indices and invert this map before lifting. The first child
contract requires support for the requested homogeneous binary or spin domain,
sense, and quadratic objective; unsupported features produce a clear diagnostic.
A later adapter can bridge domains, but must test the energy and inverse map.

There is one demonstrated status limitation in the inspected driver source:
`ExactSampler` records `OPTIMAL` in metadata, while its inherited public
`MOI.TerminationStatus()` returns `LOCALLY_SOLVED` for nonempty results.
Metadata alone must not be promoted to a public optimality certificate. The
standalone optimizer supplies its own truthful status method. Downstream tests
can use a small exact local MOI fixture that independently enumerates states and
reports `OPTIMAL`, and also test composition with the existing `ExactSampler`
with its conservative public status. Record this narrow evidence in #87; an
upstream ExactSampler status correction is useful but is not compulsory for
building the composite. No general metadata/refactoring API is presumed missing.

### Serial Reference Algorithm

A solve begins by clearing old solutions/status/counters and rebuilding a
snapshot of the current form, labels, index maps and adjacency. Validate and
copy all data that the invocation will use. Capture start values by current
variable identity: use valid specified values and fill unspecified binary
values with `0`, spin values with `-1`. Reject invalid specified values rather
than projecting them. This produces a complete incumbent, whose energy is
computed from the original coefficients. Never fill missing **child results**
from that incumbent: initial-state construction and accepting a returned child
assignment are distinct operations.

Let ``n`` be the number of free logical variables in that snapshot and ``B``
the child budget. MOI-fixed variables already eliminated by the driver remain
recoverable through its public result interface. Count the cardinality of the
selected variable set, including isolates, rather than nonzeros, edges, matrix
width alone, or separate row/column counts. ToQUBO encoded bits, auxiliary bits
and slack bits are all logical child variables; source-variable count is not
the capacity measure.

1. For ``n=0`` return the one empty assignment and its constant energy, with
   zero child calls and `OPTIMAL`. A nonempty identically constant objective
   likewise returns the full incumbent with `OPTIMAL`; detect constancy only
   after domain normalization, including a zero scale.
2. For ``0<n\le B`` and a nonconstant objective, make one whole-model child
   call, without partitioning. Validate its complete candidates, independently
   evaluate the original objective, and return the best candidate (or the
   initial incumbent when the failure rules below require it). Preserve its
   valid public termination status unless a parent limit, failure or validation error
   intervenes. This is pass-through of the optimization problem/status, not a
   promise to reproduce its entire sample distribution.
3. Otherwise find connected components of the nonzero quadratic interaction
   graph over **all** ``1:n`` indices. Sort components by minimum index. Solve
   each component of size at most ``B`` once, conditioned on the current
   complement. Isolates are singleton components. Mark exactness per component
   only after a valid `OPTIMAL` child solve and complete result processing.
4. In `:components` mode, preflight every component size before any child call.
   An oversized component terminates with `INVALID_OPTION`, the initial
   incumbent and a diagnostic giving component size and ``B``. The default
   `:components_then_sweeps` instead queues oversized components for bounded
   neighborhood sweeps. Small components are not repeatedly solved.
5. Within each oversized component, visit anchor indices in ascending order
   each sweep. A neighborhood contains its anchor plus at most ``B-1`` distinct
   adjacent variables, ranked by descending absolute quadratic coefficient,
   then ascending index for ties. Do not pad with unrelated variables. When
   ``B=1`` the neighborhood is exactly the anchor. Neighborhoods may overlap;
   execution is serial and every call conditions on the latest incumbent.
6. Stop at a work/deadline limit or after `stagnation_sweeps` complete sweeps
   without a strict improvement. A sweep visits all queued anchors once; an
   interrupted sweep counts as started but not completed. Incremental counters
   and stop reason must make this distinction visible.

The reference path deliberately spends one child call per fitting component.
For a nonconstant linear-only model with ``n>B``, that is ``n`` singleton calls;
a smaller `max_child_calls` returns a partial incumbent with `ITERATION_LIMIT`,
without a separable optimality claim. Packing disjoint components into calls
of at most ``B`` variables is a later, separately tested optimization under
#75. It is not required to implement this first serial reference path.

Each child operation follows the same transaction:

```text
check remaining parent budgets
select U, verify 1 <= length(unique(U)) <= B
fix every i outside U to the current incumbent[i]
reduced, delta, original_to_reduced = fix_variables(original_form, fixed)
create/copy/configure child; solve; read public status and results
validate each returned reduced assignment and map it back to reduced order
full = lift_state(reduced_state, fixed, original_to_reduced, n)
evaluate full against original coefficients; compare in original sense
commit only a strict improvement; retain a complete incumbent throughout
```

`fix_variables` returns an original-index → reduced-index map; it is not a
model-label map. Use `QUBOTools.index(model, label)` and
`QUBOTools.variable(model, index)` at the label boundary, keeping the explicit
order throughout. Check map bijectivity and coverage. The returned reduced
form already includes the **unscaled** offset delta in its offset: never add
`delta` again to its energy. A component's conditioned objective includes the
fixed complement, so summing child objective values would count constants
multiple times. Recompute the final full energy instead.

For finite energies, accept ``E_{new}<E_{old}`` for Min or ``E_{new}>E_{old}``
for Max; an equal value retains the incumbent. Use a stable index order for
summation and selection. For tests, use exact integer/rational scalar oracles
where possible and a stated floating-point tolerance only for equality checks;
no positive improvement tolerance may discard a provably better component
optimum while retaining an `OPTIMAL` claim. Among equally best child states,
choose lexicographic order in reduced index order. Inspect complete result
processing before making an exactness claim.

A worked independent energy identity is

```math
E(x)=2(5-3x_1+2x_2-x_3+4x_1x_2-2x_2x_3),
```

with isolated ``x_4``. Fixing binary ``x_2=1`` gives
``E=2(7+x_1-3x_3)``; fixing spin ``x_2=-1`` gives
``E=2(3-7x_1+x_3)``. The map is ``1\mapsto1,3\mapsto2,4\mapsto3``.
Enumerating all eight remaining states gives binary conditional extrema
``8,16`` and spin conditional extrema ``-10,22``. These identities are valid
for either optimization sense; the chosen extremum changes with sense.

Repeated `optimize!`, `MOI.copy_to` and `MOI.empty!` must invalidate incompatible
coefficients, dimensions, label/order mappings, starts, domain/sense, adjacency,
child state, proof flags and results. ToQUBO can recompile with changed penalties
and reassigned indices within one outer call. Object identity, unchanged
sparsity, or equal dimension is insufficient for reuse. Initial implementation
rebuilds each invocation. Later caching is allowed with a tested key/version
covering every relevant input and independent invalidation tests.

### Budgets, Statuses, Reproducibility, and Metadata

There are three separate budget scopes:

| Scope | Contract |
| :-- | :-- |
| One child | At most `B` distinct variables; optional `child_time_limit_sec`; solver-specific work limits configured in the factory |
| One composite `optimize!` | `max_child_calls`, `max_sweeps`, `max_candidate_evaluations`, stagnation, and `MOI.TimeLimitSec()` measured from invocation entry |
| One outer ToQUBO solve/refinement | `MaxPenaltyUpdates` bounds additional recompilations; it does not make the composite's per-invocation limits a shared total |

Reserve a child-call count immediately before invoking its factory, so creation,
copy/configuration failure also consumes a call attempt. Never begin another
call once that count is exhausted. Count each validated full candidate energy
evaluation, including the initial incumbent, toward the candidate cap; cap zero
permits no incumbent evaluation and returns no result. Constant/empty-model
shortcuts still require that one evaluation. Check limits during preparation,
between calls, and between result rows; counters never exceed configured caps.
The initial preparation necessary to validate input and produce a result may
itself use time. A zero time limit returns `TIME_LIMIT` with no result; a zero
child-call budget with a previously evaluated incumbent returns that incumbent.
Work limits bound dispatched calls and parent processing, not arbitrary work
hidden inside an opaque child. Exact enumeration can be exponential in ``B``.

Before each child solve, set its supported `MOI.TimeLimitSec()` to the minimum
of the child limit, the factory-configured limit, and the parent's remaining
seconds (ignoring `nothing`). Check support before setting. Record unsupported
or unenforced limits. The serial parent cannot forcibly interrupt a synchronous
child that does not enforce cancellation: it checks again when the child returns,
records overrun, and launches no further work. Do not advertise
`QUBODrivers.enforces_time_limit=true` merely because an attribute was forwarded;
the MVP advertises false. Candidate/result processing and final reconstruction
also consume the parent budget; already validated incumbents remain returnable.

The inspected, not-yet-released ToQUBO refinement loop recompiles and invokes
its child repeatedly; its forwarded `TimeLimitSec` is not a shared wall-clock
deadline. For the MVP,
document per-invocation scope and test finite update/call caps. A caller needing
an outer deadline must own a refinement loop with an absolute deadline and pass
remaining allowances each time (including compilation and feasibility checks).
The automatic refinement path must not promise that enforcement. A future
shared-deadline hook requires a concrete integration failure and a focused #244
proposal; no speculative compiler refactor is a prerequisite.

Classify the child's **public** termination status before deciding the
composite outcome. For fitting components and neighborhoods, use this explicit
policy; a complete valid row is required except for the interruption case:

| Child status | Decomposition action |
| :-- | :-- |
| `OPTIMAL` | Evaluate valid candidates; a fully processed call can certify that subproblem only |
| `LOCALLY_SOLVED`, `ALMOST_OPTIMAL`, `ALMOST_LOCALLY_SOLVED` | Evaluate as heuristic candidates, without exactness; continue while parent budgets permit |
| `TIME_LIMIT`, `ITERATION_LIMIT`, `NODE_LIMIT`, `SOLUTION_LIMIT`, `MEMORY_LIMIT`, `OBJECTIVE_LIMIT`, `NORM_LIMIT`, `OTHER_LIMIT`, `SLOW_PROGRESS` | Evaluate as heuristic candidates, record the child stop reason, and continue while parent budgets permit; a child limit does not consume a different parent scope by implication |
| `INTERRUPTED` | Stop the composite with `INTERRUPTED`, retaining its last committed incumbent; no new child row is required and no in-flight row is accepted |
| `INFEASIBLE`, `DUAL_INFEASIBLE`, `INFEASIBLE_OR_UNBOUNDED`, `LOCALLY_INFEASIBLE`, their `ALMOST_` infeasibility variants, `NUMERICAL_ERROR`, `OTHER_ERROR`, `INVALID_MODEL`, `INVALID_OPTION`, `OPTIMIZE_NOT_CALLED`, or any unclassified status | Fail with a child diagnostic; none certifies this finite unconstrained problem |

An accepted success/limit status with no complete valid row is a failure.
Always test the parent's clock and counters after a child returns: the child
status alone cannot distinguish its own deadline from the forwarded remaining
parent time. For whole-model pass-through, the same validation/failure policy
applies, but a valid success/limit status is returned unchanged after complete
processing, rather than starting further child calls.

The MVP cancellation source is Julia `InterruptException`, caught around the
parent invocation (including an exception propagated by a child). Discard the
in-flight partial candidate and return the last committed state/energy pair
with `INTERRUPTED`; convert other execution exceptions to diagnostic failures.
Tests inject this exception at internal checkpoints without sleeps. A child
that swallows interruption cannot be forcibly stopped by the parent. No MOI
cancellation-request attribute or public cancellation-token API is promised.

After input/configuration validation, use these result rules. A retained valid
full incumbent implies `ResultCount()==1`, `PrimalStatus()==FEASIBLE_POINT` for
the compiled unconstrained model, and `DualStatus()==NO_SOLUTION`. With no
validated incumbent, count is zero and primal status is `NO_SOLUTION`.
`FEASIBLE_POINT` at this layer says nothing about ToQUBO source constraints.

| Condition | Public termination status and proof rule |
| :-- | :-- |
| No solve yet, or cleared model | `OPTIMIZE_NOT_CALLED`; no stale results |
| Empty/constant objective fully evaluated | `OPTIMAL`; full valid state, possibly empty |
| Whole-model child completes validly, all returned results processed | Preserve its public status, including `OPTIMAL`, `TIME_LIMIT` or conservative `LOCALLY_SOLVED`; do not infer a proof from raw metadata |
| Every independent component fits, every child returns valid `OPTIMAL`, all components completed | `OPTIMAL`; separability supplies the global proof, with one full energy evaluation |
| Coupled neighborhoods finish or stagnate, or any component lacks an exact certificate | `LOCALLY_SOLVED` as a heuristic completion status; no global bound or certified local-minimum claim |
| Parent deadline stops decomposition | `TIME_LIMIT`; retain only validated incumbent; a per-child timeout alone follows the continuation rule above |
| Parent call, candidate, or sweep cap | `ITERATION_LIMIT`; metadata names the actual exhausted counter |
| `InterruptException` or child `INTERRUPTED` | `INTERRUPTED`; retain last committed incumbent; synchronous-child latency remains as documented |
| Non-interruption child exception, failure-class status, empty result, no complete valid result, non-finite energy, inconsistent mapping | Stop at first failure with `OTHER_ERROR`, preserve a previously validated incumbent and record child diagnostic |
| Invalid configuration / unsupported child contract / oversize in strict component mode | `INVALID_OPTION` where an invocation can return a status; setters may throw `ArgumentError`; clear prior results and give the precise diagnostic |

A child `OPTIMAL` without a valid result is a failure. Reject incomplete,
wrong-domain, non-finite or inconsistent candidates, never fabricate free
values; a malformed row invalidates that call's exactness and terminates it
with the failure rule, even if earlier rows were valid. Child `INFEASIBLE` or
`DUAL_INFEASIBLE` is inconsistent with a finite unconstrained binary/spin child
and becomes a diagnostic failure, not global infeasibility. Prioritize detected
invalid data/failure over limit status; interruption stops processing without
accepting in-flight data. Otherwise a reached **parent** limit precedes heuristic
completion. A valid early-stopped child candidate alone does not stop a sweep.
A proof completed before a later budget check remains a proof; a truncated
result scan or partial component pass cannot
claim one. Never publish a heuristic objective as a certified bound or gap.

For a configured seed ``s`` and one-based call attempt ``k``, use
``s_k=(s+k-1)\bmod(2^{31}-1)`` in exact integer arithmetic. This explicit mapping
avoids Julia's process-dependent hashing and integer overflow; log the seed and
call identity. Forward only through `QUBODrivers.RandomSeed()` when supported;
otherwise record seed support as false. The default selection/initialization
is deterministic. Reproducibility requires identical ordered model data,
package/child versions, seeds and effective work counts, and a deterministic
child. Wall-clock stops, unsupported seeding, hardware and parallel internals
can change results. Reset the call index on each composite invocation and
record the outer invocation identity separately. Do not advertise unconditional
seed determinism for arbitrary factories; `supports_seed` denotes attribute
support and test the documented deterministic-child configuration explicitly.

The MVP emits one best full assignment with constructed multiplicity **one**.
Duplicate child rows are evaluated consistently and cannot multiply the emitted
global count. In particular, never multiply component read counts to invent
joint observations. It does not honor `FinalNumberOfReads`; advertise that trait
as false. Preserve child-reported per-result multiplicities and consumed-work
metadata separately, marking unavailable physical-read totals as `nothing`.
An exact enumeration's evaluations are not physical hardware reads.

Populate the existing required schema (`origin`, `algorithm`, `backend`,
`status`, `reads`, `seeds`, `time`) and add a `"decomposition"` dictionary with:

- schema version, strategy, input dimension/frame and ordered label identity;
- configured/consumed caps, attempted/completed calls and sweeps, stagnation,
  stop reason, incomplete scan flags and timing-enforcement/overrun flags;
- candidate evaluations, accepted improvements and emitted multiplicity;
- per-call selected indices, seed/support, public child status, valid/invalid
  result counts, reported read counts and their meaning, and exactness evidence;
- original/reduced/child mapping diagnostics and optional incumbent energy trace.

`reads.number_of_reads` means full candidate evaluations consumed by this
composite; `reads.final_number_of_reads` is one (zero with no result). State this
meaning in metadata; physical child reads live only in the separate diagnostics.
Include preparation, conditioning, MOI construction/copy, execution, result
validation, lifting and full-objective evaluation in `time.effective`: the
composite algorithm is this driver's backend. Keep the generic
`MOI.SolveTimeSec() == QUBODrivers.effective_time(sampler)` convention.
Record child-execution sum and the other phase durations under `decomposition`.
Leave `time.total` to the framework's enclosing measurement, including its
post-sample callback/attachment preparation. Effective time must not exceed
that enclosing total except for documented measurement tolerance. A child-only
stopwatch does not measure decomposition. Outer compilation/refinement timing belongs to the
outer caller and is not included by pretending it ran inside the composite.

### Offline Acceptance Matrix

This table retains the accepted numerical oracles and acceptance criteria.
Runtime/conformance/compiler-integration rows 1–20 have delivered coverage in
the standalone repository; row 21 still requires release and fresh installation.
Paths now refer to the actual implementation suite; the package's
[coverage table](https://juliaqubo.github.io/QUBO.jl/QUBODecomposition.jl/dev/acceptance/)
records fixture details and limits, including the quadratic product lift used
for cubic coverage (direct nonlinear cubic source input remains unsupported).
Every numerical oracle evaluates original scalar coefficients independently of
fixing/lifting and the child's reported energy. The exact child is a test tool,
not the independent energy oracle.

| Requirement / fixture | Independent oracle and expected outcome | Downstream owner/path |
| :-- | :-- | :-- |
| Binary/spin × Min/Max × dictionary/sparse/dense forms, non-unit positive/negative scale and nonzero offset | Enumerate domain tuples; compare scalar full energy with reduced-and-lifted energy and both extrema; validate zero scale separately | `test/unit/serial.jl` |
| Worked four-variable expression above; symbol labels and reordered integer labels; internal/trailing isolates | Explicit label dictionary and scalar formula; exact map round trip, all labels returned, conditional extrema as stated | `test/unit/serial.jl` |
| Empty, all-zero/constant nonempty, one variable and all MOI-fixed variables | Hand-computed constant or two-state extrema; one complete sample, zero child calls for constant cases | `test/unit/whole_model.jl` |
| Budget one, repeated neighbor indices, oversized component, budget covering whole model; invalid zero/negative/noninteger/Bool budget | Call-recording child checks distinct-index cardinality; singleton neighborhoods at one, strict mode rejects oversize before calls, default sweeps, exactly one whole-model call | `test/unit/budgets.jl` |
| Disjoint two-variable components plus isolates, all fitting | Exhaustive **global** scalar enumeration; same Min/Max optimum as assembled exact components and `OPTIMAL` only with complete certificates | `test/unit/serial.jl` |
| Four nonconstant isolated variables, `B=2`, call cap 3 | Record three singleton calls and `ITERATION_LIMIT` with a full incumbent; no complete separable proof until all four component calls finish | `test/unit/serial.jl` |
| Coupled three/four-variable graph larger than budget, exact local child | Enumerate global optimum as a reference; every accepted full energy strictly improves in the original sense; bounded sweep termination never claims global proof | `test/unit/serial.jl` |
| Failed/throwing child, empty results, invalid domain, missing free value, false `OPTIMAL`, inconsistent map, non-finite energy | Controlled mock outputs; truthful failure, no invented values, last valid incumbent or no result; exactness revoked | `test/unit/results.jl` |
| Duplicate rows and aggregated child multiplicities, e.g. counts 3 and 7 from separate components | Count construction events directly; emitted global multiplicity remains 1, no fictitious 21 joint reads, unknown physical counts remain unknown | `test/unit/serial.jl` |
| Zero and positive call/candidate/sweep/time caps, stagnation, child ignores limit, cancellation | Injectable internal monotonic clock and scripted work advances/call counters; no timing sleeps, no extra calls, correct status, observable overrun and phase costs | `test/unit/budgets.jl`, `test/unit/serial.jl` |
| Valid child `TIME_LIMIT`/other limit statuses under a per-child cap, with parent time remaining; repeat at the parent deadline | Scripted child statuses and clock: continue to later neighborhoods in the first case, parent `TIME_LIMIT` and no next call in the second; neither case gains exactness | `test/unit/budgets.jl`, `test/unit/results.jl` |
| `InterruptException` injected before a call and during reconstruction; child `INTERRUPTED` with/without rows | Keep last committed state/energy, discard partial work, return `INTERRUPTED`, no later call; no public cancellation attribute assumed | `test/unit/results.jl` |
| Same seed/model and child; changed seed; child without seed support | Call log matches explicit modular seed formula; deterministic-child outputs repeat under work caps; unsupported case discloses limitation | `test/unit/serial.jl` |
| Reused optimizer with changed coefficients, scale/offset, domain/sense, dimension and reordered labels at equal dimension | Fresh-instance result/call log plus independent scalar evaluation; no old maps, graph, incumbent or proof flags survive | `test/unit/repeated_solves.jl` |
| Driver conformance using small exact local child and existing ExactSampler | `using Test; QUBODrivers.test(config!, Optimizer)` with all groups enabled; required metadata, complete primals, timing/read/status semantics; explicitly test the conservative ExactSampler status | `test/conformance.jl` |
| Direct `JuMP.Model(composite)` binary and spin quadratic models in both senses, nonzero constants, fixed variables | Enumerate original JuMP-domain assignments and evaluate source polynomial independently; compare returned primals/value and mapped fixed values | `test/integration/jump.jl` |
| ToQUBO constrained binary: maximize `3x1+3x2+5`, `x1+x2<=1`; deliberately low penalty then refinement | Feasible source optimum 8 by enumerating four source states; independently evaluate every compiled bit assignment, decoded source objective and constraint residual; observe changed penalty coefficients at child | `test/integration/toqubo.jl` |
| ToQUBO bounded integer and auxiliary/slack fixture in both senses: `0<=z<=3`, binary `b`, `z+2b<=3`, objective `7+2z+b`; add a separately enumerated binary cubic objective to force quadratization | Enumerate source domain for feasible Min/Max values 7/13; enumerate small compiled domains including all auxiliary/slack bits, evaluate both polynomials independently; source feasibility via residuals and public ToQUBO checks, not penalized energy alone | `test/integration/toqubo.jl` |
| Recompile same ToQUBO optimizer after coefficient/penalty/mapping changes, including same-size different encodings | Capturing child proves new coefficients and maps arrive on every invocation; compare fresh compile, decoded values and source feasibility; missing compiled bits cannot appear as valid source results | `test/integration/repeated_refinement.jl` |
| ToQUBO outer refinement versus per-invocation limits | Scripted clock/call log shows up to `1+MaxPenaltyUpdates` invocations, each with its own limits; explicit outer-loop fixture deducts compilation and child work from one deadline | `test/integration/repeated_refinement.jl` |
| Fresh-environment install and tutorial smoke | Installed package identity/version and public construction path, small exact known optimum plus larger-than-budget heuristic case, no development overrides | `examples/whole_model.jl` and `examples/serial_sweeps.jl` (fresh-install gate pending) |

The ToQUBO fixture must assert that slack/auxiliary variables were actually
introduced; a fixture that compiles them away does not cover that row. Query
`ToQUBO.violations` and, on released ToQUBO 0.7.1, enable `Attributes.PrimalFeasibilityCheck`. Automatic-refinement and
primal-status checks are not covered by installing 0.6.1 alone. In the inspected released integration `MOI.ObjectiveValue` is forwarded from the compiled child, so
independently evaluate the decoded **source** objective instead of equating the
two. Test infeasible decoded candidates as well as successful refinement. A
valid compiled optimum with inadequate penalties is not a source optimum proof.

### [Runtime Delivery and Release Handoff](@id Runtime-PR-Sequence-and-Release-Handoff)

The accepted implementation sequence has delivered the package boundary and
whole-model path, serial components/sweeps, complete driver conformance and
compiler integration. The implementation tracker and package manual preserve
the acceptance evidence. Development documentation is published, and the
[QUBODrivers catalog](https://juliaqubo.github.io/QUBODrivers.jl/dev/manual/3-samplers/)
links the external composite optimizer and composition/metadata contracts.
QUBO.jl discovery and aggregation are tracked in
[#82](https://github.com/JuliaQUBO/QUBO.jl/issues/82); deployed verification remains
required after reviewed aggregate changes merge.

General registration is the accepted first-release route. Prepare valid package
identity/license/compat and release notes, run candidate fresh-environment checks,
and register through the destination's approved maintainer workflow. Then verify
`Pkg.add("QUBODecomposition")` through the normal registry/package-server path,
with package identity, import, version and offline examples in a fresh project
and depot. Until registration and installation are verified, follow the
[checkout installation manual](https://juliaqubo.github.io/QUBO.jl/QUBODecomposition.jl/dev/start/).
There is currently no supported stable channel or v0.1.0 tag-install claim.

Release 0.1.0 only after ownership/install route are accepted, the complete MVP
matrix and ordinary platform/Julia CI pass, public docs/example run, required
upstream APIs/fixes (including the ToQUBO test/example prerequisite above) are
available at their declared minimums, and the release candidate
resolves without development overrides. Document remaining child cancellation
and reproducibility limits. Candidate fresh-install evidence is a pre-release
gate; exact-tag and registry installation evidence follow their respective
publication steps. A registry-based canary cannot be a prerequisite to the
first registration. Add it **after** registration, or use a distinct explicit-tag
composition smoke test while URL-only. Do not weaken the existing registry
freshness gate to accommodate an unregistered package.

Hand a pinned commit/tag, fixtures, child configuration, complete timing and
resource budgets to [QUBOBenchmarks#27](https://github.com/JuliaQUBO/QUBOBenchmarks.jl/issues/27)
for matched-budget direct-versus-decomposed baseline and profiling; hand the
working install/example to [QUBONotebooks#172](https://github.com/JuliaQUBO/QUBONotebooks/issues/172)
for a credential-free Julia tutorial. A small reproducible comparison and an
honest result are useful; a speedup claim or full benchmark campaign is not a
0.1.0 gate. Advanced strategies, voting, conflict repair and optimized
conditioning remain [#75](https://github.com/JuliaQUBO/QUBO.jl/issues/75).
External workflow execution remains with the separate benchmark workflow track.

Destination, accepting maintainer/release authority and General registration
route are settled. The remaining release gate is the standalone maintainer's
candidate preflight and fresh-install evidence, followed by registration/tag
and registry installation verification. The transferred
[MVP tracker](https://github.com/JuliaQUBO/QUBODecomposition.jl/issues/1) remains
open for those gates and the linked conformance, integration, tutorial and
canary handoffs in [roadmap #76](https://github.com/JuliaQUBO/QUBO.jl/issues/76).
Use references to that tracker for partial follow-ups; documentation discovery
does not itself complete the release or adoption plan.

### Inspected Sources and Reuse Limits

The original design pinned the following revisions on 2026-10-07. Current
standalone implementation and release facts were refreshed on 2026-10-09 against
[package main `7f7ea81`](https://github.com/JuliaQUBO/QUBODecomposition.jl/tree/7f7ea818fad9af229c3d871efdc3e1e679953aeb).
Historical links document evidence,
not dependencies or claims that another library proves this optimizer correct.

| Source | Reusable contract or concept and limitation |
| :-- | :-- |
| [QUBO architecture, `c0f3989`](https://github.com/JuliaQUBO/QUBO.jl/blob/c0f39896da730a40d1b90321e663e15b13215825/docs/src/design.md) | Thin entrypoint and compiler/sampler/tooling boundaries; #73 settles standalone policy ownership |
| [QUBOTools fixing/lifting, `a566070`](https://github.com/JuliaQUBO/QUBOTools.jl/blob/a566070b338fef659716db8922140e190379615e/src/library/form/form.jl), [label map](https://github.com/JuliaQUBO/QUBOTools.jl/blob/a566070b338fef659716db8922140e190379615e/src/library/model/variable_map.jl) and [conditioning manual](https://github.com/JuliaQUBO/QUBOTools.jl/blob/a566070b338fef659716db8922140e190379615e/docs/src/manual/4-models.md) | Exact fixed-boundary algebra, unscaled offset delta, original→reduced indices; retain labels separately. This is merged #139, not a new runtime API |
| [QUBOTools topology at release `42963f9`](https://github.com/JuliaQUBO/QUBOTools.jl/blob/42963f9871f2f2b0f4166963818c7b8caaa29919/src/library/form/abstract.jl) | Full declared graph dimension, including isolates; 0.16.2 is the first released fix |
| [QUBODrivers hooks, `3bf47da`](https://github.com/JuliaQUBO/QUBODrivers.jl/blob/3bf47da284f2ab8bdca9c6ab4ff0190d8d36f8be/src/interface/sampler.jl), [MOI wrapper](https://github.com/JuliaQUBO/QUBODrivers.jl/blob/3bf47da284f2ab8bdca9c6ab4ff0190d8d36f8be/src/library/sampler/wrappers/moi.jl), [metadata](https://github.com/JuliaQUBO/QUBODrivers.jl/blob/3bf47da284f2ab8bdca9c6ab4ff0190d8d36f8be/docs/src/manual/metadata.md), [test contract](https://github.com/JuliaQUBO/QUBODrivers.jl/blob/3bf47da284f2ab8bdca9c6ab4ff0190d8d36f8be/src/interface/test.jl) and [ExactSampler](https://github.com/JuliaQUBO/QUBODrivers.jl/blob/3bf47da284f2ab8bdca9c6ab4ff0190d8d36f8be/src/library/drivers/ExactSampler.jl) | Existing extension points, explicit traits and `Test` extension. Public termination and total/effective time require care as described above |
| [ToQUBO result decoding, `481ff10`](https://github.com/JuliaQUBO/ToQUBO.jl/blob/481ff101d60372124a42c49ff1f2692664b699c7/src/attributes/solver.jl), [refinement loop](https://github.com/JuliaQUBO/ToQUBO.jl/blob/481ff101d60372124a42c49ff1f2692664b699c7/src/refinement.jl) and [refinement manual](https://github.com/JuliaQUBO/ToQUBO.jl/blob/481ff101d60372124a42c49ff1f2692664b699c7/docs/src/manual/5-refinement.md) | Historical development source; refinement, primal-status checking and the later recompilation fix are now available in released ToQUBO 0.7.1. No automatic shared refinement deadline; compiled and source objectives differ |
| [QSplit neighborhood selection, `4da64b0`](https://github.com/alpha-unito/QSplit/blob/4da64b072e702953038addd51cdf54f97f0f9516/qsplit/splitting/split_k_interactions.py), [halting helpers](https://github.com/alpha-unito/QSplit/blob/4da64b072e702953038addd51cdf54f97f0f9516/qsplit/halting_heuristic/stop.py), [deprecated local runner](https://github.com/alpha-unito/QSplit/blob/4da64b072e702953038addd51cdf54f97f0f9516/qsplit/local_runner.py) and [active CWL splitter](https://github.com/alpha-unito/QSplit/blob/4da64b072e702953038addd51cdf54f97f0f9516/qsplit/cwl/cli/split.py) | Interaction ranking/control ideas. With budget one, `[-num_neighbors:]` becomes `[-0:]` and selects the whole array. Its nonzero-based variable count also omits isolates. The active CWL path uses recursive matrix splitting; it is not this serial algorithm |
| [D-Wave Hybrid decomposers, `ec17a70`](https://github.com/dwavesystems/dwave-hybrid/blob/ec17a700b0250123da9909ec82db4ecb2516993d/hybrid/decomposers.py), [induced model](https://github.com/dwavesystems/dwave-hybrid/blob/ec17a700b0250123da9909ec82db4ecb2516993d/hybrid/utils.py) and [SplatComposer](https://github.com/dwavesystems/dwave-hybrid/blob/ec17a700b0250123da9909ec82db4ecb2516993d/hybrid/composers.py) | Bounded selection, fixed-boundary terms and recomposition. `bqm_induced_by` explicitly resets offset to zero; it cannot supply Julia's full-energy identity. Neither library specifies MOI statuses |

No foreign source is adapted by this design. If later code adapts QSplit or
D-Wave Hybrid implementations, retain their applicable license/attribution
notices and pin the adapted files/revision. Mathematical correctness and Julia
status claims require the independent downstream oracles above.

## [Certified Preprocessing: Proposed First-Release Contract](@id certified-preprocessing)

This is the **unimplemented design proposal** for
[QUBO#85](https://github.com/JuliaQUBO/QUBO.jl/issues/85), under
[roadmap #84](https://github.com/JuliaQUBO/QUBO.jl/issues/84). It specifies a
shared contract for [#86](https://github.com/JuliaQUBO/QUBO.jl/issues/86)–
[#91](https://github.com/JuliaQUBO/QUBO.jl/issues/91),
[QUBOBenchmarks#30](https://github.com/JuliaQUBO/QUBOBenchmarks.jl/issues/30)
and [QUBODecomposition#16](https://github.com/JuliaQUBO/QUBODecomposition.jl/issues/16).
No preprocessing runtime, repository, package installation, manual deployment,
registration or release is delivered by this documentation slice. The accepted
decomposition design above remains in force.

### Destination and Package Boundary

Propose the public repository **JuliaQUBO/QUBOPreprocessing.jl** and matching
Julia module `QUBOPreprocessing`, with
[@bernalde](https://github.com/bernalde) as proposed accepting maintainer and
release authority. On 2026-10-09, the authenticated GitHub repository lookup
returned 404: no destination was visible to that account. Creation, ownership
acceptance, access continuity and bootstrap publication require a separate
explicit handoff. There is no working package-name install command or deployed
manual to advertise yet.

Propose **MPL-2.0**, matching the inspected QUBO.jl and QUBOTools licenses.
New files retain accurate contributor ownership; adapted files retain upstream
notices. No foreign implementation is copied by this design. Before bootstrap,
the accepting maintainer confirms the license and any obligations for material
actually reused; importing a dependency does not transfer its copyright.

| Surface | Owner and dependency direction |
| :-- | :-- |
| Model, labels, domain, sense, scale, offset, supplied-fixing algebra and lifting | Existing QUBOTools public APIs |
| Certified decisions, arithmetic, scope, reversible workspace, safe export and reconstruction | QUBOPreprocessing → QUBOTools plus used Julia standard libraries |
| Optional direct sampler consumer | QUBOPreprocessing Julia extension with QUBODrivers/MOI weak dependencies; plain workspace use does not load the extension |
| Compilation, encoding, penalties and source feasibility | ToQUBO/PBO; JuMP and ToQUBO in integration/test/example environments |
| Search, separators, components, incumbent and parent budgets | QUBODecomposition → preprocessing at its later integration; no reverse dependency |
| Comparative cost and operating envelope | QUBOBenchmarks#30; benchmark harness stays outside the core |
| Discovery and eventual registry canary | QUBO.jl; no runtime implementation or automatic re-export here |

The proposed core floor is **Julia 1.10 and QUBOTools 0.16.2** (`julia = "1.10"`,
`QUBOTools = "0.16.2"`, allowing compatible 0.16.x). The optional extension
proposes **QUBODrivers 0.6.5 and MOI 1** (`QUBODrivers = "0.6.5"`,
`MathOptInterface = "1"`). Inspected upstream projects declare those Julia and
compatibility lines; the existing decomposition package uses these floors.
This is source compatibility evidence, not a destination installation test:
bootstrap must exercise the actual minimum versions in a fresh Julia 1.10
project and current compatible versions in another project. JuMP 1 and ToQUBO
0.7.1 are proposed integration floors, separately resolved; do not force JuMP
into a pinned MOI 1.0.0 test when its own minimum requires a later MOI.

There is no new mandatory JuMP, solver, Python, QPU, external process,
QUBODecomposition or graph-flow dependency. QUBOTools itself already imports
Graphs and other tooling dependencies: this proposal does not claim a tiny
transitive dependency footprint. Additional heavy preprocessing methods must
have no import or initialization cost in the default cheap path.

### Guarantee and Numerical Transport

Let the represented source objective be

```math
E(x)=\alpha\left(\beta+\sum_i L_i x_i+\sum_{i<j}Q_{ij}x_i x_j\right),
```

with its recorded domain and minimization/maximization sense. The first release
accepts finite `Float64` stored coefficients, scale and offset. Their **exact
binary values** define the mathematical problem; ordinary rounded evaluation
is not its proof oracle. Reject nonfinite input and unsupported coefficient
types explicitly, without silently converting them. Both binary and spin
models, arbitrary ordered labels, isolates, empty models and finite negative,
nonunit and zero scales are supported. Offset is inside the scale as above.

Let `A` be the explicit caller assumptions and `D` the committed strict
certified deductions. Substituting `A ∪ D` produces residual `R` with lifting
map `lift`. For every complete valid residual state, exact represented energy
satisfies `E(lift(y)) = R(y)`. Every optimum of the source restricted by `A`
agrees with `D`; consequently a global residual optimum lifts to a global
optimum **of that restricted problem**. When `A` is empty this is the original
problem, and strict dominance preserves every original optimum. A caller's
separator assignment is an assumption, never a globally certified fixing.
Weak persistency, heuristic fixing, sample consensus, approximate pruning and
unproved restrictions are outside 0.1.0.

Three claims stay separate: exact reduction/transport, the child's exact
residual solve, and the invocation's original global certificate. Certified
preprocessing cannot upgrade an uncertified child. An all-fixed or constant
residual can be solved locally with a complete original-domain assignment;
free zero-scale variables stay free under strict dominance, although any
complete state then optimizes the constant objective. A branch-local proof
needs the outer algorithm's complete branch coverage before becoming an
original global proof. A compiled ToQUBO certificate does not establish source
feasibility or source optimality under invalid encoding or insufficient penalties.
Sampling distributions and physical read counts are not preserved promises.

For decisions, normalize to minimization by the sense and the **sign** of
scale, avoiding eager floating multiplication that can overflow; zero scale
admits no strict deduction. In the binary domain, bound the current linear
field by `L_i = a_i + sum(min(0,b_ij))` and
`U_i = a_i + sum(max(0,b_ij))`: a proven `L_i > 0` fixes 0 and a proven
`U_i < 0` fixes 1. In spin, use `a_i ± sum(abs(b_ij))`, fixing -1/+1 for a
strictly positive/negative field. Fixed-boundary contributions are included.
Ties and uncertain signs abstain. Deterministic dirty-queue order makes bounded
traces reproducible for equal inputs and work limits; deadlines may change the
amount of completed work.

The selected first-release arithmetic policy is a conservative enclosure fast
path plus **bounded exact dyadic fallback on affected expressions**, with
abstention when neither establishes strict sign. #87 owns its implementation
and independent verifier. Enclosures must cover incremental updates and
rollback; ordinary sums, epsilons and `isapprox` are not certificates. Keep exact
expression provenance sufficient to reconstruct witnesses without converting
the entire source to big integers on each update. Overflow, nonfinite
intermediates, exhausted proof allowance or unresolved sign cannot commit a
fixing. No process-global rounding mode may race between workspaces. Exact
fallback time, storage and arithmetic work are observable, including operand
sizes; an arithmetic operation count alone is not a constant-time claim.

**Export is a separate certification gate.** Sound deductions do not justify
rounding a residual into a different optimization problem. The 0.1.0 default
`materialize(ws; coefficient_type=Float64, limits=...)` succeeds only when all
residual coefficients, constant and scale can be transported exactly to the
requested representation, with a complete energy identity and map. This gate
also applies to further adapter conversions, including scale folding and MOI
quadratic conventions. Recomputed sample energy or a tolerance agreement does
not establish preservation of argmin. A future order-preserving transform needs
its own proof; it is not the first-release fallback.

If reduced export is unsafe and `A` is empty, return an explicitly marked
**identity fallback** using the unchanged supported source snapshot, without
any exported deductions; its reconstruction is identity and its certificate
chain is empty. It need not modify the workspace's valid internal deductions.
If assumptions are active, never drop them to return an unrestricted source:
return `:unsupported_transport` with **no solver model**, retaining the valid
workspace for rollback or a consumer that supports the exact restriction.
Interrupted export similarly returns no partial model. An adapter unable to
transport even the original source exactly must decline a certified route;
an ordinary solve may proceed only under its explicitly weaker child contract.
No reduction/export failure authorizes an original-problem `OPTIMAL` claim.

### Workspace Ownership, Scope and Proposed API

All names below are **proposed and unimplemented**. There is one workspace
implementation, shared by incremental and one-shot use; no generic rule plugin
framework is needed for the initial identity/strict-dominance stages.

`Workspace(model; rules=:dominance)` copies the represented objective and
ordered label mapping into a private immutable source snapshot, then owns all
mutable adjacency, fields, enclosures, masks, dirty queue, buffers and undo
trail. `rules=:identity` selects no inference. A caller still owns its input;
workspace changes never mutate it, and later caller edits do not silently alter
the snapshot. Labels must have stable equality/hash semantics; callers may not
mutate label identities while retained. There is no shared mutable workspace
state between concurrent callers, and one workspace is used serially.

The opaque generation binds the snapshot's coefficients, penalties as embodied
in those coefficients, domain, sense, scale, offset, dimension and ordered
variable mappings. `generation(ws)` returns that identity. `reset!(ws, model)`
constructs a new snapshot/generation in O(n+m) preparation, invalidating **all**
old checkpoints, reports, assumptions, proofs and live query views. Failed
validation leaves the old workspace intact. Arbitrary incremental coefficient
editing is not supported in 0.1.0. Consumers must reset or construct anew after
any source/reformulation/penalty change, including same-dimension relabeling;
no hidden full-model hash/scan is done on every hot call. Reuse requires the
consumer to establish that the source generation is unchanged.

| Proposed call | Return and mutation contract |
| :-- | :-- |
| `checkpoint(ws)` | Opaque token for workspace, generation and exact retained trail/queue prefix; O(1), no model copy |
| `assume!(ws, label => value)` | `MutationReport` with scope, changed-event range and work counts; validates original label/domain and commits an explicit assumption transaction |
| `propagate!(ws; limits=...)` | `PropagationReport` with current state token, scope, changed-event range, stop reason, per-call and cumulative work; commits only verified deductions and retains unfinished queue |
| `changes(ws, checkpoint_or_report)` | Borrowed iterator over fixed/unfixed/provenance events since a retained checkpoint, or that report's event range; O(1) creation, O(k) traversal, no full graph scan/copy |
| `rollback!(ws, cp)` | `MutationReport` for undo events and costs; restores fields, constants, masks, queue, scopes and proof validity to `cp` |
| `unfix!(ws, label)` | `MutationReport`; removes a caller assumption using the replay path below; does not arbitrarily remove a proved deduction |
| `materialize(ws; coefficient_type=Float64, limits=...)` | Owned `ExportResult`: `:certified`, `:identity_fallback`, `:unsupported_transport`, or a bounded-stop reason; model/map/certificate only on success |
| `reconstruct(export_result, y)` | Owned complete original-order state plus original-energy evaluation record; validates export, state length/domain and map coverage; no workspace mutation |
| `preprocess(model; rules=:dominance, limits=...)` | `(workspace, propagation_report)` built by construction plus `propagate!`; materialization remains explicit even on the one-shot path |

`assume!` repeats an already explicit identical assignment as a no-op. A matching
certified value may be recorded as a new **explicit** assumption, so replay
retains the caller's choice independently of the deduction. A conflicting
current fixing, invalid label/value or malformed limit throws `ArgumentError`
transactionally. To explore a value conflicting with a deduction, restore a
checkpoint before that deduction or use a fresh identity workspace, impose the
assumption, then propagate; root deductions are not premises for arbitrary
contrary branches. `unfix!` on an absent assumption is a no-op; on a deduction
without a caller assumption it fails, since removing a proof premise requires
rollback rather than inventing an assumption. Changing an assumed value is
unfix/restore followed by a new assumption, never an overwrite.

Mandatory records distinguish `:global_deduction`, `:assumption` and
`:conditional_deduction`. A deduction is global only with an empty assumption
scope and global predecessors. Otherwise it is conservatively conditional,
even if a stronger proof might exist. Compact immutable scope nodes refer to
parent and assumption ID rather than copying every active assumption into every
record. Each deduction stores generation, original index/value, rule, scope,
bound enclosure or exact witness reference, and predecessor references sufficient
for independently structured re-verification. Reports retain counts and stop
reason with verbose tracing off; detailed diagnostics/proof serialization are
explicit extra work. A source hash authenticates identity, not the mathematics.

Checkpoints are workspace-specific retained-prefix capabilities. Reject foreign,
old-generation and discarded-future tokens, including a token at the same trail
length on a different branch. The rollback target and ancestors remain usable;
its discarded descendants cannot be reused. Queries/views are borrowed and expire
on the next mutation; callers copy only needed events before mutating. Reports'
state/proof validity is checked against the current generation and retained
branch, not merely variable values. A report from an undone branch cannot be
consumed as current evidence. An owned successful export is a frozen snapshot:
rollback does not rewrite it, but it still certifies only its recorded historical
source/scope; a consumer must match those identities before treating it as current.

LIFO rollback undoes recorded changes, including conditional descendants, before
further propagation/export. A non-LIFO `unfix!` conservatively rolls back to the
retained baseline **before the first active caller assumption**, discards all
conditional deductions, and replays only retained explicit assumptions in their
original order, omitting the removed assumption. Re-propagation is a subsequent
explicit bounded call; replay never promotes old deductions to assumptions.
Independent root deductions at that baseline may remain. Scope descendants and
their checkpoints/reports are invalidated. The operation costs O(undone trail +
retained assumption inventory + replayed touched adjacency), plus later actual
propagation; it may revisit a whole active branch. It is not O(degree) arbitrary
unfix. #89 must test matching-deduction assumptions, conflicting branches and
multiple removals against fresh scoped enumeration.

### Bounds, Costs and Resumption

`limits` is a validated record with nonnegative integer caps (excluding `Bool`)
for examined terms, committed deductions and exact-fallback steps, and an optional
finite nonnegative remaining time in seconds, converted to a monotonic deadline.
Default propagation work caps are unbounded; consumers select finite caps for
inner-loop use. Zero allowance permits inspection but no new charged work.
Reports expose examined variables/edges/terms, queue work, committed deductions,
trail writes/undos, fallback count/steps/operand sizes, elapsed time and overrun;
materialization and reconstruction costs are recorded separately. Counters are
monotonic for performed work and are not refunded by rollback. Each resume gets
an explicit new allowance; a parent deducts all prior calls from its total.

Stop reasons are `:quiescent`, `:all_fixed`, `:work_limit`, `:proof_limit`,
`:deadline`, `:interrupted` and `:numeric_uncertainty`. The first two describe
completion of the selected rules, not solver optimality. Numerical uncertainty
without available fallback leaves the candidate unfixed and records why; a
caller can resume with more proof allowance or accept that certified prefix.
Deadline/interruption/work stops retain pending candidates, without duplicating
committed deductions or losing dirty flags. A no-change quiescent call returns
in O(1); a blocked candidate is not repeatedly rescanned without a relevant
field change or explicit additional proof allowance.

One fixing's adjacency update is transactional. The first release requires a
transaction-sized structural allowance; it does not retain a partially applied
adjacency update across calls. On a pre-commit `:work_limit` refusal, the report
includes `required_next_terms`: a conservative sufficient grant for the pending
fixing's remaining structural examination and update work, tied to its current
state token. Proof allowance and deadline remain separate requirements. Cache
this refusal while that state is unchanged: equal insufficient grants perform
no repeated candidate scan or adjacency update and need not make progress.
A caller must grant the reported structural allowance (and adequate proof/time
allowance), or keep the valid prefix. The required grant is invalidated by a
relevant state change, rollback or reset; it is not a whole-model estimate.

Reserve bounded work before committing; if a limit or interruption arrives
mid-update, undo its partial writes and retain the candidate for resumption.
Returned state always contains only complete verified transactions. Clock checks
surround bounded units;
cooperative cancellation can overrun by one such unit and its restoration cost,
which must be reported. An exact fallback must itself have bounded resumable or
abortable steps; an unbounded big-integer call is not a hard deadline guarantee.
`assume!`, `rollback!` and replay must finish or restore a valid pre-call state
before returning/throwing; they do not promise a caller's propagation deadline
bounds their mandatory restoration cost. Parent algorithms charge those costs.

| Operation | Cost contract, before measurement |
| :-- | :-- |
| Sparse snapshot/preparation | O(n+m) storage and structural work, reusable signed adjacency/maps/buffers; dense input conversion can inspect O(n²) entries once |
| Fixing and propagation | Touched adjacency, queue and actual cascades plus bounded proof work; no constant-time promise for global cascades |
| Checkpoint/no-change changes query | O(1) token/view; enumerate only actual events, O(k); no hidden residual construction |
| Rollback | Proportional to undone trail changes, including queue and proof bookkeeping |
| Non-LIFO replay | Explicit branch undo/inventory/replay cost above; potentially whole branch |
| Full materialization/proof export | Explicit O(n+m) structural traversal/copy plus certified arithmetic/transport and requested proof output; caller-owned result |
| Complete reconstruction/energy | O(n+m) traversal plus chosen numeric evaluation/verification cost; complete original state, never fill missing child values silently |

Structural big-O counts exclude variable-size proof arithmetic, whose costs are
reported separately. No claimed performance benefit follows from this design.
The default pass is cheap dominance; later probing or roof-duality requires
separate selection, bounds, proof semantics and measured adoption.

For [QUBOBenchmarks#30](https://github.com/JuliaQUBO/QUBOBenchmarks.jl/issues/30),
acceptance must record cold/JIT setup and memory against n,m; warmed no-change,
single bounded-degree update, short/global cascades, LIFO rollback and non-LIFO
replay latency/allocations; uncertainty/fallback/verification; materialization
and full reconstruction; and end-to-end direct/decomposition solves. Compare
incremental reuse, rebuilding each step and preprocessing off with identical
assumptions, child/start/seeds and total budgets. Include sparse/disconnected,
dense, no-reduction and near-cancellation fixtures, guarded tiny exact oracles,
versions/source hashes, machine/environment, repetitions, variability and failures.

Set concrete acceptable overhead/break-even targets from the baseline before
accepting results. Disclose the amortization iteration count and avoid double
counting proof or solver time. Deterministic CI checks count touched work and
allocation growth to detect whole-model scans on unrelated components; noisy
wall-time thresholds and large campaigns stay optional. The intended repeated
sparse workload must improve complete cycle time and allocations versus rebuilding,
or the implementation/adoption envelope must be revised. Record accept/revise/defer
for expensive methods and no-benefit cases; variable reduction alone is insufficient.

### Independent Acceptance Matrix and Consumer Boundary

These are future implementation checks, **not tests executed by this design PR**.
Oracles must use independent scalar polynomials and exact binary-value rational
references on guarded tiny instances, rather than merely compare two calls to
the same conditioner/verifier. Cost-shape assertions complement numerical tests.

| Contract and failure surface | Owner | Independent acceptance evidence |
| :-- | :-- | :-- |
| Identity/no-op, empty/constant/all-fixed, isolates and ordered labels | #85 identity skeleton; #86 | Enumerate complete original states; identity maps and unchanged coefficients; all-fixed empty residual has original fixed-state energy |
| Binary/spin; Min/Max; positive, negative, nonunit and zero scale; offsets | #85–#88 | Independent scalar/exact energies for every guarded state and reconstructed state; zero scale/ties produce no strict fixings |
| Strict dominance and cascades, graph splits | #88 with #87 | Enumerate all scoped optima and show every deduction holds in each; solve residual exactly and compare optimum values |
| Global, assumption and conditional provenance | #87/#89 | A deduction triggered only by an assumption is never global; tampered premises/bounds/values/generation rejected by independent verifier |
| Nested rollback and non-LIFO unfix/replay | #86/#89 | Randomized bounded traces versus fresh scoped enumeration; restore fields/constants/queue/maps; remove an assumption and invalidate descendants before reuse |
| Checkpoint/view/report misuse | #86/#89 | Foreign/stale/same-length different-branch/discarded-future tokens fail; copied exports retain historical scope; live consumers reject stale current-state evidence |
| Coefficient/penalty/domain/sense/scale/offset/label-map generation changes | #85/#86/#89; #90 consumer | Same-size changes and ToQUBO recompilation reset all premises/maps; compare fresh instances; no hot-call whole-model fingerprint scan |
| Cancellation, adjacent floats, subnormals, huge values, overflow and unsafe export | #87 | Exact dyadic oracle; rounding changes argmin counterexamples; uncertainty abstains; transport fails or identity-falls back as specified; active assumptions never disappear |
| Interrupted/resumed propagation/export and exact fallback | #86–#89 | Scripted clock/work/interrupts at transaction boundaries; complete valid prefix, unfinished queue, no duplicate/refunded work, no partial exported model; a fixing with degree above a small grant reports refusal/required allowance without repeated hidden work, then completes with sufficient structural/proof/time grants |
| No-change/local updates and unavoidable cascade/replay costs | #86/#88/#89; Benchmarks#30 | Instrument touched adjacency/trail/queue and allocations after warmup, verify untouched components are not scanned/copied; report complete replay/fallback costs |
| Direct plain-workspace and optional sampler consumer | #90 | Core imports without adapter; exact/heuristic/malformed/empty/failed child scripts; complete lifting and truthful scope-qualified status; all-fixed skips child |
| ToQUBO compiled bits, encoding/penalties and source feasibility | #90 | Restore every compiled bit before decoding; independent source objective/constraint residuals, including infeasible candidates and changed penalties |
| Root preprocessing and capacity/status/deadline composition | Decomposition#16 | On/off exhaustive comparison, preprocessor-induced component split, MOI-fixed plus reduced-map composition, parent costs, stale generation rejection and unchanged off/default behavior |
| Installation, documentation, floors and release/adoption | #85 bootstrap; #91 | Fresh candidate/minimum/current resolution, then separately tag/registry/import identity and runnable examples; served docs/canary verified after publication |

Issue numbers in this matrix refer to QUBO.jl while incubated; their links in the
opening paragraph identify the current trackers. After an authorized transfer,
refresh references preserving GitHub redirects and history.

The first optional adapter (#90) creates a fresh supplied child, materializes
through the export gate, validates complete residual states, reconstructs every
original variable and reports independently evaluated original energy. It charges
preprocessing, fallback, export, child and reconstruction to one parent budget,
keeping only a fully validated incumbent on timeout/failure. A public child
`OPTIMAL` is reusable only with a matching scope and complete certified transport
chain. QUBODrivers' ExactSampler has a conservative public status; a separately
verified exhaustive test adapter may expose its certificate without changing the
shared driver contract. Empty/partial/malformed results invent neither bits nor
proofs. Scope-restricted success is not unrestricted original `OPTIMAL`.

Decomposition#16 separately owns **opt-in root preprocessing** before residual
component discovery and capacity checks. Automatic preprocessing of every
neighborhood or separator branch is not the default and needs separate complete
cost evidence. Exact separator conditioning has priority over deferred graph
partition sweeps (#13); neither those sweeps nor another strategy is a prerequisite
for this contract. The existing shared conditioner remains the reference until
profiling demonstrates a specific upstream optimization gap.

### Proposed Usage (Not Executable Yet)

The following is pseudocode for the proposed contract; it is deliberately a
plain `julia` block, not a runnable Documenter example. `model` is a caller-owned
QUBOTools model, and `solve_residual` is a consumer with its own status/proof contract.

```julia
ws = Workspace(model; rules=:dominance)
root = propagate!(ws; limits=root_allowance)
cp = checkpoint(ws)
try
    assume!(ws, :separator_bit => 1) # explicit restriction, not a global proof
    branch = propagate!(ws; limits=branch_allowance)
    for event in changes(ws, cp)    # consume before next mutation; no residual copy
        inspect(event)
    end
    exported = materialize(ws; coefficient_type=Float64, limits=export_allowance)
    if exported.status == :certified
        child_result = solve_residual(exported.model)
        # Validate child state/status; its proof applies only to exported.scope.
        full_state, energy = reconstruct(exported, child_result.state)
    end
finally
    rollback!(ws, cp)               # invalidates branch consequences before reuse
end

# One-shot convenience uses the same workspace; export is still explicit.
ws_once, report = preprocess(model; rules=:dominance, limits=one_shot_allowance)
exported_once = materialize(ws_once; coefficient_type=Float64, limits=export_allowance)
```

This example assumes the chosen branch value does not conflict with the root's
current deductions. For a contrary branch use a checkpoint before those deductions
or a fresh identity workspace as specified above. A consumer handles all export
statuses and validates its child before reconstruction/certificate propagation.

### Bootstrap, Issue Transfer and Release Sequence

This PR completes the proposed architecture/API/acceptance contract of #85 for
human review. Repository existence, accepted maintainer/license, actual package
identity-path tests and isolated minimum/current installs remain **outstanding**.
No #85 checkbox for delivered runtime or installation is satisfied by prose.

The next separately authorized bootstrap handoff creates the public destination,
records accepting maintainer/release continuity and MPL notices, and opens a focused
skeleton/identity-path draft PR there. It includes `Project.toml` with a new UUID
and verified compat, `src/QUBOPreprocessing.jl`, separate `docs/Project.toml`,
`docs/make.jl`, `test/runtests.jl` and identity fixtures, README, CONTRIBUTING and
release instructions. Adopt the ecosystem's minimum/current Julia CI, optional
Windows support lane, docs workflow and Dependabot maintenance policy; contribution
policy requires human review of AI-assisted changes. The rule set initially stays
empty (`:identity`), exposing snapshot/generation, explicit materialization and
complete identity reconstruction without claiming dominance is implemented.
Test empty/constants, labels/isolates/domains/senses/scales/offsets and source
ownership in an isolated project before expanding the API. A candidate 0.1.0
project version is not a tag, registry entry or published release.

After the destination exists and is accepted, a separately authorized administrative
step transfers package-local children #85–#91 (retaining the remaining #85 bootstrap
criteria) and later package-local children when approved; preserve history/redirects
and refresh epic, matrix and dependency links. QUBO#84 remains the ecosystem roadmap,
Benchmarks#30 the evidence owner and Decomposition#16 the integration owner. This
PR transfers no issues and creates no repositories or settings.

The dependency order is: identity bootstrap → aligned **workspace (#86) and
arithmetic (#87)** → strict dominance (#88) → reversible scoped updates (#89) →
direct consumers (#90) and accepted cost evidence (Benchmarks#30) → core release
(#91) → production decomposition integration (Decomposition#16). Benchmark fixtures
start with the workspace; candidate downstream integration may use explicitly pinned
isolated source environments before release, without a production dependency cycle.

For eventual General registration, the accepting maintainer verifies candidate
metadata/license/compat/release notes and independent correctness/performance gates,
then fresh candidate install/import/examples at actual minimum/current versions.
A separately authorized release executes merged source → Registrator submission →
General merge → matching tag/release through the documented TagBot/maintainer route
→ fresh registry install/import/examples with source/version identity. Verify served
package docs, then QUBO discovery/canary and downstream normally resolving dependency
floors. There is no registration/tag/install action in this design slice and no
forced ecosystem package release without a runtime/compatibility change.

### Refreshed Evidence and Reuse Limits

Inspected on 2026-10-09; source compatibility and precedents are distinct from
execution evidence for the proposed package.

| Pinned source | Relevant contract and limitation |
| :-- | :-- |
| [QUBOTools conditioning manual](https://github.com/JuliaQUBO/QUBOTools.jl/blob/3da98ae2baafb84f49e1dbe1360d9d055590e4cd/docs/src/manual/4-models.md), [fix/lift implementation](https://github.com/JuliaQUBO/QUBOTools.jl/blob/3da98ae2baafb84f49e1dbe1360d9d055590e4cd/src/library/form/form.jl), [compat](https://github.com/JuliaQUBO/QUBOTools.jl/blob/3da98ae2baafb84f49e1dbe1360d9d055590e4cd/Project.toml) | Original→reduced map retains free order/isolates; labels separate; offset delta is unscaled and already included. Float roundoff is allowed by this shared helper, so certified transport still needs #87's gate |
| [Merged separator PR #21](https://github.com/JuliaQUBO/QUBODecomposition.jl/pull/21), [transaction](https://github.com/JuliaQUBO/QUBODecomposition.jl/blob/3c35523f5586dbaf59994748c1b746200ceb0879/src/solve.jl), [separator implementation](https://github.com/JuliaQUBO/QUBODecomposition.jl/blob/3c35523f5586dbaf59994748c1b746200ceb0879/src/separator.jl), [result contract](https://github.com/JuliaQUBO/QUBODecomposition.jl/blob/3c35523f5586dbaf59994748c1b746200ceb0879/docs/src/results.md) | Private branch state, complete validated lifting/original-energy commit, global proof needs complete separator coverage and certified residual components. Its Float64/public-child contract is not formal exact transport certification for the new engine |
| [Separator cost evidence](https://github.com/JuliaQUBO/QUBODecomposition.jl/blob/3c35523f5586dbaf59994748c1b746200ceb0879/examples/separator/README.md) | Three tiny-fixture separator medians were about 7.1×, 12.6× and 6.7× slower than direct exhaustive solving at producing revision b8bf8ad; invocation totals include conditioning, while per-call conditioning fields are zero. This motivates measuring complete costs, not replacing the shared conditioner on these timings alone |
| [Decomposition policy](https://github.com/JuliaQUBO/QUBODecomposition.jl/blob/3c35523f5586dbaf59994748c1b746200ceb0879/CONTRIBUTING.md), [compat](https://github.com/JuliaQUBO/QUBODecomposition.jl/blob/3c35523f5586dbaf59994748c1b746200ceb0879/Project.toml), [driver compat](https://github.com/JuliaQUBO/QUBODrivers.jl/blob/3485f22d2544c61265717729e53e6ddca0e0789b/Project.toml), [Maintenance Policy](@ref) | Ownership, human review, Julia/dependency floors and separate release/publication gates; not proof that the new destination installs |
