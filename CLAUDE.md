# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

DBus.jl is a pure-Julia D-Bus interface using `Dbus_jll` (no system libdbus required). Provides connection management, message construction, argument serialization, synchronous method calls, signal emission, and a service dispatch loop. Linux/FreeBSD only. Requires Julia 1.10+.

## Common Commands

### Testing

```bash
# Run all tests (--threads=2 required for service round-trip tests)
julia --threads=2 --project=. -e 'using Pkg; Pkg.test(; julia_args=`--threads=2`)'

# Run tests interactively (uses TestItemRunner with @testitem macros)
julia --threads=2 --project=. -e 'using TestItemRunner; @run_package_tests()'
```

Tests use `@testitem` macros with tags (`:unit`, `:fast`, `:integration`, `:slow`). Integration tests require a running D-Bus session bus.

### Formatting and Linting

```bash
# Format Julia code (4-space indent, 92-char margin)
julia -e 'using JuliaFormatter; format(".")'

# Run all pre-commit checks (formatting, markdown lint, YAML lint, etc.)
pre-commit run -a
```

## Architecture

```
src/
├── DBus.jl         # module root — includes all files, exports public API
├── types.jl        # C constants, type-code tables, Julia↔DBus mapping
├── error.jl        # DBusError exception + with_dbus_error(f) helper
├── connection.jl   # DBusConnection — connect, name, match rules
├── message.jl      # DBusMessage — construction, field accessors
├── iter.jl         # argument serialisation (append) and deserialisation (read)
├── call.jl         # call_method, send_message, send_reply, send_error
├── signal.jl       # send_signal
└── service.jl      # DBusService, register_object, run dispatch loop
```

All `ccall`s go through `Dbus_jll.libdbus`. Key design decisions:

- **Shared vs private connections**: `dbus_bus_get` returns shared connections that must NOT be closed (only unref'd). The `DBusConnection.shared` field tracks this.
- **Bool widening**: D-Bus `dbus_bool_t` is 4 bytes (`Cuint`), not 1 byte. All Bool append/read goes through `Cuint` conversion.
- **String append**: `dbus_message_iter_append_basic` for strings expects `const char**`. Pass `Ref(pointer(s))` with `GC.@preserve`.
- **Iterator buffers**: `DBusMessageIter` is a stack-allocated C struct. We use `zeros(UInt8, 128)` buffers with `GC.@preserve` and convert `pointer(buf)` to `Ptr{Cvoid}`.
- **Service dispatch loop**: `read_write_dispatch` is a blocking C call. Service round-trip tests require `Threads.@spawn` (multiple OS threads).

## Conventions

- **Formatting**: JuliaFormatter with 4-space indent, 92-char margin, Unix line endings (`.JuliaFormatter.toml`)
- **Branch naming**: `<issue-number>-<description>` (e.g., `42-add-feature`), prefixes for small changes (`typo-`, `hotfix-`)
- **Commits**: Imperative/present tense ("Add feature", "Fix bug")
- **CI coverage targets**: 90% project, 90% patch (codecov.yml)
- **Workspace**: `Project.toml` declares workspace member `test`
