# Release checklist

Use this checklist for every tagged release of `QUBO.jl`. The Zenodo concept DOI
`10.5281/zenodo.7909165` (concept record `7909165`) is the permanent software
identifier for `QUBO.jl`; never create a new top-level concept record for a
routine release.

## Before tagging

- [ ] Follow the [accepted ecosystem stewardship decision](https://github.com/JuliaQUBO/QUBO.jl/issues/66#issuecomment-5153544965):
      David Bernal (`@bernalde`) is the sole designated Zenodo owner for now.
      Confirm **Can manage** access to deposit `7909165` and all future
      versions, or record outstanding access recovery/transfer work and the
      review date in `JuliaQUBO/QUBO.jl#66`.
- [ ] Revisit adding a backup manager annually or whenever maintainership
      changes. A single-owner arrangement is accepted while no other maintainer
      has volunteered; use personal accounts and never share a password or API
      token.
- [ ] Update `version` in `Project.toml` and `docs/Project.toml` (`[compat] QUBO`).
- [ ] Update `version` and `date-released` in `CITATION.cff`. Keep the evergreen
      concept DOI `10.5281/zenodo.7909165`, `MPL-2.0` license, and preferred
      journal article citation (`10.1080/10556788.2026.2702926`) unchanged.
- [ ] Validate the Citation File Format schema:

      ```sh
      cffconvert --validate --infile CITATION.cff
      ```

- [ ] Run the package test suite (which enforces package, compatibility, and
      citation metadata invariants in `test/package_metadata.jl`):

      ```sh
      julia --project=. -e 'using Pkg; Pkg.test()'
      ```

## After publishing the GitHub release

- [ ] Confirm that the `Zenodo release verification` GitHub Actions workflow
      (`.github/workflows/zenodo.yml`) passed, or run
      `julia --project=. scripts/verify_zenodo_release.jl <release-tag>` to
      verify that Zenodo published a **new version** under
      `10.5281/zenodo.7909165` matching the official GitHub release tag and
      version, `MPL-2.0` license, `https://github.com/JuliaQUBO/QUBO.jl`
      repository URL, and Julia package UUID
      (`ce8c2e91-a970-4681-856b-16178c24a30c`).
- [ ] Verify the version DOI resolves to that exact archive and the concept DOI
      resolves to the latest archived release:

      ```sh
      curl --fail --location --output /dev/null https://doi.org/<version-doi>
      curl --fail --location --output /dev/null https://doi.org/10.5281/zenodo.7909165
      curl --fail --location https://zenodo.org/api/records/<version-record-id>
      ```

- [ ] Download the Zenodo archive, record and verify its checksum, confirm it
      contains the tagged `Project.toml` version, and verify its source commit
      matches the GitHub release tag.
- [ ] Record the new Zenodo version DOI in the GitHub release notes and update
      the exact-version entries in `CITATION.cff` (`identifiers`),
      `CITATION.bib` (`@software`), `README.md`, and `docs/src/index.md` in a
      reviewed follow-up PR.
