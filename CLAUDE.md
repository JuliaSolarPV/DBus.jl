# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

DBus.jl is a Julia package under the JuliaSolarPV organization, scaffolded with BestieTemplate.jl. Currently early-stage (v0.1.0). Requires Julia 1.10+.

## Common Commands

### Testing

```bash
# Run all tests
julia --project=. -e 'using Pkg; Pkg.test()'

# Run tests interactively (uses TestItemRunner with @testitem macros)
julia --project=. -e 'using TestItemRunner; @run_package_tests()'
```

Tests use `@testitem` macros with tags (`:unit`, `:fast`, `:integration`, `:slow`, `:validation`). Shared setup uses `@testsnippet` and `@testmodule` blocks in `test/test-basic-test.jl`.

### Formatting and Linting

```bash
# Format Julia code (4-space indent, 92-char margin)
julia -e 'using JuliaFormatter; format(".")'

# Run all pre-commit checks (formatting, markdown lint, YAML lint, etc.)
pre-commit run -a
```

### Documentation

```bash
# Build and serve docs locally with live reload
julia --project=docs -e 'using Pkg; Pkg.develop(PackageSpec(path=pwd())); using LiveServer; servedocs()'
```

## Architecture

- `src/DBus.jl` — Main module, all exports defined here
- `test/runtests.jl` — Test entry point using TestItemRunner
- `test/test-basic-test.jl` — Test items with tag-based organization
- `docs/make.jl` — Documenter.jl setup with automatic page discovery via `recursively_list_pages()`

## Conventions

- **Formatting**: JuliaFormatter with 4-space indent, 92-char margin, Unix line endings (`.JuliaFormatter.toml`)
- **Branch naming**: `<issue-number>-<description>` (e.g., `42-add-feature`), prefixes for small changes (`typo-`, `hotfix-`)
- **Commits**: Imperative/present tense ("Add feature", "Fix bug")
- **CI coverage targets**: 90% project, 90% patch (codecov.yml)
- **Workspace**: `Project.toml` declares workspace members `test` and `docs`
