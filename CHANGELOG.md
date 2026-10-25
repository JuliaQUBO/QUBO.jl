# Changelog

## 0.6.4 (2026-10-25)

- Add the JuMP-native `QUBO.Karp21` constrained problem library covering all 21
  Karp NP-complete problems with `ToQUBO.jl` compilation and MQT QAO
  (`arXiv:2406.12840`) parity (#68, #69, #101).
- Add `QUBODecomposition.jl` and `QUBOPreprocessing.jl` ecosystem discovery,
  aggregate documentation manuals, and two-tier registry canaries (#99, #100).
- Standardize `QUBO.jl` citation metadata (`CITATION.cff`, `CITATION.bib`),
  Zenodo concept/version DOI guidance, and `.github/RELEASE_CHECKLIST.md` (#66,
  #102).

## 0.6.3 (2026-10-12)

- Support registered ToQUBO 0.7.1 and later 0.7 patch releases while retaining
  compatibility with ToQUBO 0.4, 0.5, and 0.6.
- Align documentation compatibility and add regression checks for the 0.7.1
  lower bound and the canary's stale/missing core package detection.

The registry-only ecosystem canary recovers only after this patch reaches
General and both existing tiers pass with registered packages. Source candidate
validation is separate evidence.
