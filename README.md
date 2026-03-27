# DBus.jl

[![Test workflow status](https://github.com/JuliaSolarPV/DBus.jl/actions/workflows/Test.yml/badge.svg?branch=main)](https://github.com/JuliaSolarPV/DBus.jl/actions/workflows/Test.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/JuliaSolarPV/DBus.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/JuliaSolarPV/DBus.jl)
[![Lint workflow Status](https://github.com/JuliaSolarPV/DBus.jl/actions/workflows/Lint.yml/badge.svg?branch=main)](https://github.com/JuliaSolarPV/DBus.jl/actions/workflows/Lint.yml?query=branch%3Amain)

DBus.jl is a pure-Julia interface to [D-Bus](https://www.freedesktop.org/wiki/Software/dbus/), the standard inter-process communication system on Linux. It uses [`Dbus_jll`](https://github.com/JuliaBinaryWrappers/Dbus_jll.jl) so no system `libdbus` installation is required.

- **High-level API** -- `call_method`, `send_signal`, and a service dispatch loop
- **Low-level access** -- direct `DBusMessage` construction, argument serialization, and raw sends
- **Correct lifetime management** -- Julia finalizers handle `unref` calls automatically
- **No system dependencies** -- bundled `libdbus` via `Dbus_jll` (Linux and FreeBSD)

## Example Usage

```julia
using DBus

# Connect to the session bus
conn = DBusConnection(DBUS_BUS_SESSION)

# Call a method on the bus daemon
names = call_method(
    conn,
    "org.freedesktop.DBus",
    "/org/freedesktop/DBus",
    "org.freedesktop.DBus",
    "ListNames",
)
println(names[1])  # Vector of bus name strings

# Get the unique connection name
println(unique_name(conn))  # e.g. ":1.42"

close(conn)
```

### Sending Signals

```julia
conn = DBusConnection(DBUS_BUS_SESSION)

send_signal(
    conn,
    "/com/example/MyObj",
    "com.example.MyInterface",
    "SomethingHappened";
    args=(Int32(42), "hello"),
)

close(conn)
```

### Running a Service

```julia
conn = DBusConnection(DBUS_BUS_SESSION)
request_name(conn, "com.example.MyService")

svc = DBusService(conn)
register_object(
    svc,
    "/com/example/Obj",
    "com.example.Iface",
    "Echo" => (conn, msg, args) -> send_reply(conn, msg; args=tuple(args...)),
)

# Blocks until stop(svc) is called
run(svc)
```

## Platform Support

| Platform | Supported |
|---|---|
| Linux (x86\_64, aarch64, armv7, i686, ppc64le) | Yes |
| FreeBSD (x86\_64) | Yes |
| macOS | No |
| Windows | No |

## How to Cite

If you use DBus.jl in your work, please cite using the reference given in [CITATION.cff](https://github.com/JuliaSolarPV/DBus.jl/blob/main/CITATION.cff).

## Contributing

If you want to make contributions of any kind, please first take a look at our [contributing guide](https://github.com/JuliaSolarPV/DBus.jl/blob/main/docs/src/90-contributing.md).
