# ──────────────────────────────────────────────────────────────────
# DBusConnection — connect to a bus, manage lifetime
# ──────────────────────────────────────────────────────────────────

"""
    DBusConnection

Wraps a `DBusConnection*` from libdbus. Obtain one via:

    DBusConnection(DBUS_BUS_SESSION)      # session bus
    DBusConnection(DBUS_BUS_SYSTEM)       # system bus
    DBusConnection(address::String)       # explicit address

The connection is reference-counted by libdbus; a Julia finalizer calls
`dbus_connection_unref` on GC. Call `close(conn)` to actively disconnect.
"""
mutable struct DBusConnection
    ptr::Ptr{Cvoid}
    is_open::Bool
    shared::Bool  # true for dbus_bus_get connections (must not call close)

    function DBusConnection(ptr::Ptr{Cvoid}; shared::Bool = false)
        ptr == C_NULL && throw(ArgumentError("Null DBusConnection pointer"))
        conn = new(ptr, true, shared)

        # libdbus defaults to calling exit() on disconnect — disable that
        ccall(
            (:dbus_connection_set_exit_on_disconnect, libdbus),
            Cvoid,
            (Ptr{Cvoid}, Cuint),
            ptr,
            Cuint(0),
        )

        finalizer(conn) do c
            if c.ptr != C_NULL
                ccall((:dbus_connection_unref, libdbus), Cvoid, (Ptr{Cvoid},), c.ptr)
                c.ptr = C_NULL
            end
        end

        return conn
    end
end

function _check_conn(conn::DBusConnection)
    conn.ptr == C_NULL &&
        throw(ArgumentError("DBusConnection has been closed or finalized"))
    return nothing
end

# ── Constructors ──────────────────────────────────────────────────

"""
    DBusConnection(bus_type::Integer; private=false)

Connect to a well-known bus. `bus_type` should be one of
`DBUS_BUS_SESSION`, `DBUS_BUS_SYSTEM`, or `DBUS_BUS_STARTER`.

When `private=true`, opens a dedicated connection via `dbus_bus_get_private`
instead of the shared one. Use this when you need multiple independent
connections to the same bus (e.g. a service + client in the same process).
"""
function DBusConnection(bus_type::Integer; private::Bool = false)
    if private
        ptr = with_dbus_error() do err
            ccall(
                (:dbus_bus_get_private, libdbus),
                Ptr{Cvoid},
                (Cint, Ptr{Cvoid}),
                Cint(bus_type),
                err,
            )
        end
        return DBusConnection(ptr; shared = false)
    else
        ptr = with_dbus_error() do err
            ccall((:dbus_bus_get, libdbus), Ptr{Cvoid}, (Cint, Ptr{Cvoid}), Cint(bus_type), err)
        end
        return DBusConnection(ptr; shared = true)
    end
end

"""
    DBusConnection(address::AbstractString)

Connect to a D-Bus daemon at the given address string and register on the bus.
"""
function DBusConnection(address::AbstractString)
    ptr = with_dbus_error() do err
        ccall((:dbus_connection_open, libdbus), Ptr{Cvoid}, (Cstring, Ptr{Cvoid}), address, err)
    end
    with_dbus_error() do err
        ccall((:dbus_bus_register, libdbus), Cuint, (Ptr{Cvoid}, Ptr{Cvoid}), ptr, err)
    end
    return DBusConnection(ptr)
end

# ── Lifecycle ─────────────────────────────────────────────────────

function Base.close(conn::DBusConnection)
    if conn.ptr != C_NULL && conn.is_open
        # Shared connections (from dbus_bus_get) must not be closed —
        # only unref'd. Calling close on them causes libdbus to abort.
        if !conn.shared
            ccall((:dbus_connection_close, libdbus), Cvoid, (Ptr{Cvoid},), conn.ptr)
        end
        conn.is_open = false
    end
    return nothing
end

function Base.isopen(conn::DBusConnection)
    conn.ptr == C_NULL && return false
    conn.is_open || return false
    connected =
        ccall((:dbus_connection_get_is_connected, libdbus), Cuint, (Ptr{Cvoid},), conn.ptr)
    return connected != 0
end

# ── I/O ───────────────────────────────────────────────────────────

"""
    flush(conn::DBusConnection)

Block until all pending outgoing messages have been written to the socket.
"""
function Base.flush(conn::DBusConnection)
    _check_conn(conn)
    ccall((:dbus_connection_flush, libdbus), Cvoid, (Ptr{Cvoid},), conn.ptr)
    return nothing
end

"""
    read_write_dispatch(conn; timeout_ms=100) -> Bool

Drive the connection's I/O: read incoming data, write pending data,
and dispatch any complete messages. Returns `false` if the connection
has been disconnected.
"""
function read_write_dispatch(conn::DBusConnection; timeout_ms::Integer = 100)
    _check_conn(conn)
    ret = ccall(
        (:dbus_connection_read_write_dispatch, libdbus),
        Cuint,
        (Ptr{Cvoid}, Cint),
        conn.ptr,
        Cint(timeout_ms),
    )
    return ret != 0
end

# ── Bus queries ───────────────────────────────────────────────────

"""
    unique_name(conn::DBusConnection) -> String

Return the unique bus name assigned to this connection (e.g. `":1.42"`).
"""
function unique_name(conn::DBusConnection)
    _check_conn(conn)
    p = ccall((:dbus_bus_get_unique_name, libdbus), Ptr{Cchar}, (Ptr{Cvoid},), conn.ptr)
    p == C_NULL && error("Connection has no unique name")
    return unsafe_string(p)
end

"""
    request_name(conn, name; flags=DBUS_NAME_FLAG_DO_NOT_QUEUE) -> Cint

Request ownership of a well-known bus name. Returns one of the
`DBUS_REQUEST_NAME_REPLY_*` constants.
"""
function request_name(
    conn::DBusConnection,
    name::AbstractString;
    flags::Integer = DBUS_NAME_FLAG_DO_NOT_QUEUE,
)
    _check_conn(conn)
    ret = with_dbus_error() do err
        ccall(
            (:dbus_bus_request_name, libdbus),
            Cint,
            (Ptr{Cvoid}, Cstring, Cuint, Ptr{Cvoid}),
            conn.ptr,
            name,
            Cuint(flags),
            err,
        )
    end
    return ret
end

"""
    add_match(conn, rule)

Add a match rule so that messages matching `rule` are delivered to this
connection. The rule string follows the D-Bus match rule syntax, e.g.
`"type='signal',interface='org.example.Foo'"`.
"""
function add_match(conn::DBusConnection, rule::AbstractString)
    _check_conn(conn)
    with_dbus_error() do err
        ccall(
            (:dbus_bus_add_match, libdbus),
            Cvoid,
            (Ptr{Cvoid}, Cstring, Ptr{Cvoid}),
            conn.ptr,
            rule,
            err,
        )
    end
    return nothing
end
