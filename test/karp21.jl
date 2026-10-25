function _exact_toqubo_optimizer()
    return () -> ToQUBO.Optimizer(ExactSampler.Optimizer)
end

function _assert_best_feasible(model::JuMP.Model)
    rep = ToQUBO.feasibility_report(model)
    @test !isempty(rep.results)
    @test rep.results[1].feasible
    @test rep.results[1].violation_count == 0
    return rep
end

function test_karp21()
    @testset "Karp-21 JuMP Problem Library" begin
        @test length(Karp21.PROBLEMS) == 21
        @test [p.karp_index for p in Karp21.PROBLEMS] == collect(1:21)

        # 1. Satisfiability (SAT & Max-SAT)
        sat_model = Karp21.satisfiability(
            3,
            [[1, 2], [-1, 3], [-2, -3]];
            hard_clauses = true,
            optimizer = _exact_toqubo_optimizer(),
        )
        optimize!(sat_model)
        _assert_best_feasible(sat_model)

        maxsat_model = Karp21.sat(
            2,
            [[1], [-1], [2]];
            hard_clauses = false,
            optimizer = _exact_toqubo_optimizer(),
        )
        optimize!(maxsat_model)
        _assert_best_feasible(maxsat_model)
        @test objective_value(maxsat_model) ≈ 2.0

        # 2. 0-1 Integer Programming
        A_ip = [1 1 0; 0 1 1]
        b_ip = [1, 1]
        c_ip = [3.0, 1.0, 2.0]
        ip_model = Karp21.zero_one_integer_programming(
            A_ip,
            b_ip;
            c = c_ip,
            sense = :EqualTo,
            optimizer = _exact_toqubo_optimizer(),
        )
        optimize!(ip_model)
        _assert_best_feasible(ip_model)
        @test objective_value(ip_model) ≈ 1.0
        @test round.(Int, value.(ip_model[:x])) == [0, 1, 0]

        # 3. Clique & Independent Set
        # Triangle (1,2,3) plus pendant vertex 4 attached to 3
        edges_clique = [(1, 2), (2, 3), (1, 3), (3, 4)]
        clique_model = Karp21.clique(
            4,
            edges_clique;
            optimizer = _exact_toqubo_optimizer(),
        )
        optimize!(clique_model)
        _assert_best_feasible(clique_model)
        @test objective_value(clique_model) ≈ 3.0
        @test round.(Int, value.(clique_model[:x])) == [1, 1, 1, 0]

        indep_model = Karp21.independent_set(
            4,
            edges_clique;
            optimizer = _exact_toqubo_optimizer(),
        )
        optimize!(indep_model)
        _assert_best_feasible(indep_model)
        @test objective_value(indep_model) ≈ 2.0

        # 4. Set Packing
        sp_model = Karp21.set_packing(
            [1, 2, 3, 4],
            [[1, 2], [2, 3], [3, 4]];
            weights = [2.0, 3.0, 2.0],
            optimizer = _exact_toqubo_optimizer(),
        )
        optimize!(sp_model)
        _assert_best_feasible(sp_model)
        @test objective_value(sp_model) ≈ 4.0
        @test round.(Int, value.(sp_model[:x])) == [1, 0, 1]

        # 5. Vertex Cover
        vc_model = Karp21.vertex_cover(
            4,
            edges_clique;
            optimizer = _exact_toqubo_optimizer(),
        )
        optimize!(vc_model)
        _assert_best_feasible(vc_model)
        @test objective_value(vc_model) ≈ 2.0

        # 6. Set Cover
        sc_model = Karp21.set_cover(
            [1, 2, 3],
            [[1, 2], [2, 3], [1]];
            weights = [1.0, 1.0, 5.0],
            optimizer = _exact_toqubo_optimizer(),
        )
        optimize!(sc_model)
        _assert_best_feasible(sc_model)
        @test objective_value(sc_model) ≈ 2.0
        @test round.(Int, value.(sc_model[:x])) == [1, 1, 0]

        # 7. Directed Feedback Vertex Set
        # Directed 3-cycle 1 -> 2 -> 3 -> 1: removing 1 vertex breaks the cycle
        fvs_model = Karp21.feedback_vertex_set(
            3,
            [(1, 2), (2, 3), (3, 1)];
            weights = [2.0, 1.0, 3.0],
            optimizer = _exact_toqubo_optimizer(),
        )
        optimize!(fvs_model)
        _assert_best_feasible(fvs_model)
        @test objective_value(fvs_model) ≈ 1.0
        @test round.(Int, value.(fvs_model[:x])) == [0, 1, 0]

        # 8. Directed Feedback Arc Set
        fas_model = Karp21.feedback_arc_set(
            3,
            [(1, 2), (2, 3), (3, 1)];
            weights = [4.0, 1.0, 3.0],
            optimizer = _exact_toqubo_optimizer(),
        )
        optimize!(fas_model)
        _assert_best_feasible(fas_model)
        @test objective_value(fas_model) ≈ 1.0
        @test round.(Int, value.(fas_model[:y])) == [0, 1, 0]

        # 9. Directed Hamiltonian Cycle
        dhc_model = Karp21.directed_hamiltonian_cycle(
            3,
            [(1, 2), (2, 3), (3, 1)];
            optimizer = _exact_toqubo_optimizer(),
        )
        optimize!(dhc_model)
        _assert_best_feasible(dhc_model)
        dhc_x = round.(Int, value.(dhc_model[:x]))
        @test [ dhc_x[v, pos] for v in 1:3, pos in 1:3 ] == [1 0 0; 0 1 0; 0 0 1]

        # 10. Undirected Hamiltonian Cycle, Hamiltonian Path, and TSP
        uhc_model = Karp21.hamiltonian_cycle(
            3,
            [(1, 2), (2, 3), (1, 3)];
            optimizer = _exact_toqubo_optimizer(),
        )
        optimize!(uhc_model)
        _assert_best_feasible(uhc_model)

        hpath_model = Karp21.hamiltonian_path(
            3,
            [(1, 2), (2, 3)];
            start_vertex = 1,
            end_vertex = 3,
            optimizer = _exact_toqubo_optimizer(),
        )
        optimize!(hpath_model)
        _assert_best_feasible(hpath_model)

        dist_tsp = [
            0.0 1.0 5.0
            5.0 0.0 1.0
            1.0 5.0 0.0
        ]
        tsp_model = Karp21.travelling_salesman(
            dist_tsp;
            optimizer = _exact_toqubo_optimizer(),
        )
        optimize!(tsp_model)
        _assert_best_feasible(tsp_model)
        @test objective_value(tsp_model) ≈ 3.0

        # 11. 3-SAT
        threesat_model = Karp21.three_sat(
            3,
            [[1, 2, 3], [-1, 2], [-2, 3]];
            optimizer = _exact_toqubo_optimizer(),
        )
        optimize!(threesat_model)
        _assert_best_feasible(threesat_model)
        @test_throws ArgumentError Karp21.three_sat(4, [[1, 2, 3, 4]])

        # 12. Chromatic Number & Graph Coloring
        gc_model = Karp21.graph_coloring(
            3,
            [(1, 2), (2, 3)],
            2;
            optimizer = _exact_toqubo_optimizer(),
        )
        optimize!(gc_model)
        _assert_best_feasible(gc_model)

        chrom_model = Karp21.chromatic_number(
            3,
            [(1, 2), (2, 3)],
            2;
            optimizer = _exact_toqubo_optimizer(),
        )
        optimize!(chrom_model)
        _assert_best_feasible(chrom_model)
        @test objective_value(chrom_model) ≈ 2.0

        # 13. Clique Cover
        # Two disjoint edges (1,2) and (3,4) covered by 2 cliques
        cc_model = Karp21.clique_cover(
            4,
            [(1, 2), (3, 4)],
            2;
            optimizer = _exact_toqubo_optimizer(),
        )
        optimize!(cc_model)
        _assert_best_feasible(cc_model)

        # 14. Exact Cover
        ec_model = Karp21.exact_cover(
            [1, 2, 3],
            [[1, 2], [3], [2, 3]];
            weights = [1.0, 1.0, 4.0],
            optimizer = _exact_toqubo_optimizer(),
        )
        optimize!(ec_model)
        _assert_best_feasible(ec_model)
        @test objective_value(ec_model) ≈ 2.0
        @test round.(Int, value.(ec_model[:x])) == [1, 1, 0]

        # 15. Hitting Set
        hs_model = Karp21.hitting_set(
            [1, 2, 3],
            [[1, 2], [2, 3]];
            weights = [3.0, 1.0, 3.0],
            optimizer = _exact_toqubo_optimizer(),
        )
        optimize!(hs_model)
        _assert_best_feasible(hs_model)
        @test objective_value(hs_model) ≈ 1.0
        @test round.(Int, value.(hs_model[:x])) == [0, 1, 0]

        # 16. Steiner Tree
        # Path 1 - 2 - 3 with terminals {1, 3}: must include vertex 2 and both edges
        st_model = Karp21.steiner_tree(
            3,
            [(1, 2), (2, 3), (1, 3)],
            [1, 3];
            weights = [1.0, 1.0, 5.0],
            optimizer = _exact_toqubo_optimizer(),
        )
        optimize!(st_model)
        _assert_best_feasible(st_model)
        @test objective_value(st_model) ≈ 2.0

        # 17. 3-Dimensional Matching
        tdm_model = Karp21.three_dimensional_matching(
            [(1, 1, 1), (1, 2, 2), (2, 2, 2)];
            weights = [2.0, 1.0, 2.0],
            optimizer = _exact_toqubo_optimizer(),
        )
        optimize!(tdm_model)
        _assert_best_feasible(tdm_model)
        @test objective_value(tdm_model) ≈ 4.0
        @test round.(Int, value.(tdm_model[:m])) == [1, 0, 1]

        # 18. Knapsack & Subset Sum
        ks_model = Karp21.knapsack(
            [2, 3, 4],
            [3, 4, 8],
            5;
            optimizer = _exact_toqubo_optimizer(),
        )
        optimize!(ks_model)
        _assert_best_feasible(ks_model)
        @test objective_value(ks_model) ≈ 8.0
        @test round.(Int, value.(ks_model[:x])) == [0, 0, 1]

        ss_model = Karp21.subset_sum(
            [2, 3, 6],
            5;
            optimizer = _exact_toqubo_optimizer(),
        )
        optimize!(ss_model)
        _assert_best_feasible(ss_model)
        @test round.(Int, value.(ss_model[:x])) == [1, 1, 0]

        # 19. Job Sequencing
        # 2 jobs: t = [1, 2], deadlines = [1, 3], penalties = [5, 4]
        # Ordering job 1 then job 2 finishes at 1 <= 1 and 3 <= 3 -> 0 penalty
        js_model = Karp21.job_sequencing(
            [1, 2],
            [1, 3],
            [5, 4];
            optimizer = _exact_toqubo_optimizer(),
        )
        optimize!(js_model)
        _assert_best_feasible(js_model)
        @test objective_value(js_model) ≈ 0.0

        # 20. Number Partition
        np_model = Karp21.number_partition(
            [1, 2, 3];
            exact = true,
            optimizer = _exact_toqubo_optimizer(),
        )
        optimize!(np_model)
        _assert_best_feasible(np_model)
        np_x = round.(Int, value.(np_model[:x]))
        @test np_x == [1, 1, 0]

        # 21. Max-Cut (edge list and adjacency matrix)
        mc_model = Karp21.max_cut(
            3,
            [(1, 2), (2, 3), (1, 3)];
            weights = [1.0, 2.0, 3.0],
            optimizer = _exact_toqubo_optimizer(),
        )
        optimize!(mc_model)
        _assert_best_feasible(mc_model)
        @test objective_value(mc_model) ≈ 5.0

        adj_mc = [
            0.0 1.0 3.0
            1.0 0.0 2.0
            3.0 2.0 0.0
        ]
        mc_adj_model = Karp21.max_cut(adj_mc; optimizer = _exact_toqubo_optimizer())
        optimize!(mc_adj_model)
        _assert_best_feasible(mc_adj_model)
        @test objective_value(mc_adj_model) ≈ 5.0
    end

    return nothing
end

