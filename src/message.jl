# ──────────────────────────────────────────────────────────────────
# DBusMessage — construction and field accessors
# ──────────────────────────────────────────────────────────────────

"""
    DBusMessage

Wraps a `DBusMessage*` from libdbus. Construct via:

    DBusMessage(dest, path, iface, method)        # method call
    DBusMessage(Val(:signal), path, iface, name)   # signal

A finalizer calls `dbus_message_unref` unless `owns=false`.
"""
mutable struct DBusMessage
    ptr::Ptr{Cvoid}

    function DBusMessage(ptr::Ptr{Cvoid}; owns::Bool = true)
        ptr == C_NULL && throw(ArgumentError("Null DBusMessage pointer"))
        msg = new(ptr)
        if owns
            finalizer(msg) do m
                if m.ptr != C_NULL
                    ccall((:dbus_message_unref, libdbus), Cvoid, (Ptr{Cvoid},), m.ptr)
                    m.ptr = C_NULL
                end
            end
        end
        return msg
    end
end

function _check_msg(msg::DBusMessage)
    msg.ptr == C_NULL && throw(ArgumentError("DBusMessage has been freed"))
    return nothing
end

# ── Constructors ──────────────────────────────────────────────────

"""
    DBusMessage(dest, path, iface, method)

Create a method-call message addressed to `dest` at object `path`,
interface `iface`, method name `method`.
"""
function DBusMessage(
    dest::AbstractString,
    path::AbstractString,
    iface::AbstractString,
    method::AbstractString,
)
    ptr = ccall(
        (:dbus_message_new_method_call, libdbus),
        Ptr{Cvoid},
        (Cstring, Cstring, Cstring, Cstring),
        dest,
        path,
        iface,
        method,
    )
    return DBusMessage(ptr)
end

"""
    DBusMessage(Val(:signal), path, iface, name)

Create a signal message from object `path`, interface `iface`, signal `name`.
"""
function DBusMessage(
    ::Val{:signal},
    path::AbstractString,
    iface::AbstractString,
    name::AbstractString,
)
    ptr = ccall(
        (:dbus_message_new_signal, libdbus),
        Ptr{Cvoid},
        (Cstring, Cstring, Cstring),
        path,
        iface,
        name,
    )
    return DBusMessage(ptr)
end

# ── Field accessors ───────────────────────────────────────────────

function _nullable_string(p::Ptr{Cchar})
    return p == C_NULL ? nothing : unsafe_string(p)
end

"""    destination(msg) — message destination bus name or `nothing`."""
function destination(msg::DBusMessage)
    _check_msg(msg)
    p = ccall((:dbus_message_get_destination, libdbus), Ptr{Cchar}, (Ptr{Cvoid},), msg.ptr)
    return _nullable_string(p)
end

"""    object_path(msg) — object path or `nothing`."""
function object_path(msg::DBusMessage)
    _check_msg(msg)
    p = ccall((:dbus_message_get_path, libdbus), Ptr{Cchar}, (Ptr{Cvoid},), msg.ptr)
    return _nullable_string(p)
end

"""    interface(msg) — interface name or `nothing`."""
function interface(msg::DBusMessage)
    _check_msg(msg)
    p = ccall((:dbus_message_get_interface, libdbus), Ptr{Cchar}, (Ptr{Cvoid},), msg.ptr)
    return _nullable_string(p)
end

"""    member(msg) — method or signal name, or `nothing`."""
function member(msg::DBusMessage)
    _check_msg(msg)
    p = ccall((:dbus_message_get_member, libdbus), Ptr{Cchar}, (Ptr{Cvoid},), msg.ptr)
    return _nullable_string(p)
end

"""    sender(msg) — sender bus name or `nothing`."""
function sender(msg::DBusMessage)
    _check_msg(msg)
    p = ccall((:dbus_message_get_sender, libdbus), Ptr{Cchar}, (Ptr{Cvoid},), msg.ptr)
    return _nullable_string(p)
end

"""    error_name(msg) — error name (for error messages) or `nothing`."""
function error_name(msg::DBusMessage)
    _check_msg(msg)
    p = ccall((:dbus_message_get_error_name, libdbus), Ptr{Cchar}, (Ptr{Cvoid},), msg.ptr)
    return _nullable_string(p)
end

"""
    reply_serial(msg) -> UInt32

Return the serial number of the message this is a reply to.
"""
function reply_serial(msg::DBusMessage)
    _check_msg(msg)
    return ccall((:dbus_message_get_reply_serial, libdbus), Cuint, (Ptr{Cvoid},), msg.ptr)
end

"""
    message_type(msg) -> Cint

Return the message type (`DBUS_MESSAGE_TYPE_METHOD_CALL`, etc.).
"""
function message_type(msg::DBusMessage)
    _check_msg(msg)
    return ccall((:dbus_message_get_type, libdbus), Cint, (Ptr{Cvoid},), msg.ptr)
end
