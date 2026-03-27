"""
    DBus

Pure-Julia interface to D-Bus via `Dbus_jll`. Provides connection
management, message construction, argument serialisation, synchronous
method calls, signal emission, and a simple service dispatch loop.

# Quick start

```julia
using DBus

conn = DBusConnection(DBUS_BUS_SESSION)
names = call_method(conn, "org.freedesktop.DBus", "/org/freedesktop/DBus",
                    "org.freedesktop.DBus", "ListNames")
close(conn)
```
"""
module DBus

using Dbus_jll: libdbus

include("types.jl")
include("error.jl")
include("connection.jl")
include("message.jl")
include("iter.jl")
include("call.jl")
include("signal.jl")
include("service.jl")

# ── Public API ────────────────────────────────────────────────────

export DBusConnection,
    DBusMessage,
    DBusError,
    DBusService,
    # Constants — bus types
    DBUS_BUS_SESSION,
    DBUS_BUS_SYSTEM,
    DBUS_BUS_STARTER,
    # Constants — message types
    DBUS_MESSAGE_TYPE_METHOD_CALL,
    DBUS_MESSAGE_TYPE_METHOD_RETURN,
    DBUS_MESSAGE_TYPE_ERROR,
    DBUS_MESSAGE_TYPE_SIGNAL,
    # Connection
    flush,
    read_write_dispatch,
    unique_name,
    request_name,
    add_match,
    # Message accessors
    destination,
    object_path,
    interface,
    member,
    sender,
    error_name,
    reply_serial,
    message_type,
    # Serialisation
    append_args!,
    read_args,
    # Call API
    call_method,
    send_message,
    send_reply,
    send_error,
    # Signal
    send_signal,
    # Service
    register_object,
    stop

end # module DBus
