# Changelog

## 0.6.3 (unreleased)

- Support registered ToQUBO 0.7.1 and later 0.7 patch releases while retaining
  compatibility with ToQUBO 0.4, 0.5, and 0.6.
- Align documentation compatibility and add regression checks for the 0.7.1
  lower bound and the canary's stale/missing core package detection.

The registry-only ecosystem canary recovers only after this patch reaches
General and both existing tiers pass with registered packages. Source candidate
validation is separate evidence. Refresh the software version and release date
in `CITATION.cff` when the release is published; its current fields describe the
latest published release.
