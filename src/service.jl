# ──────────────────────────────────────────────────────────────────
# DBusService — register objects and run a dispatch loop
# ──────────────────────────────────────────────────────────────────

"""
    DBusService

A simple D-Bus service that dispatches incoming method calls to registered
Julia handler functions.

    svc = DBusService(conn)
    register_object(svc, "/com/example/Obj", "com.example.Iface",
                    "Hello" => (conn, msg, args) -> send_reply(conn, msg; args=("world",)))
    run(svc)
"""
mutable struct DBusService
    conn::DBusConnection
    handlers::Dict{String,Dict{String,Dict{String,Function}}}
    stop_channel::Channel{Bool}

    function DBusService(conn::DBusConnection)
        return new(
            conn,
            Dict{String,Dict{String,Dict{String,Function}}}(),
            Channel{Bool}(1),
        )
    end
end

"""
    register_object(svc, path, iface, pairs...)

Register method handlers for `iface` at `path`. Each pair maps a method
name to a handler function `(conn, msg, args) -> ...`. The handler should
call `send_reply` or `send_error` to respond.
"""
function register_object(
    svc::DBusService,
    path::AbstractString,
    iface::AbstractString,
    pairs::Pair{String,<:Function}...,
)
    path_dict = get!(() -> Dict{String,Dict{String,Function}}(), svc.handlers, path)
    iface_dict = get!(() -> Dict{String,Function}(), path_dict, iface)
    for (method_name, handler) in pairs
        iface_dict[method_name] = handler
    end
    return nothing
end

"""
    run(svc::DBusService; timeout_ms=100)

Block and dispatch incoming messages until `stop(svc)` is called or the
connection drops.
"""
function Base.run(svc::DBusService; timeout_ms::Integer = 100)
    conn = svc.conn
    while isopen(conn)
        if isready(svc.stop_channel)
            take!(svc.stop_channel)
            break
        end

        read_write_dispatch(conn; timeout_ms = timeout_ms)

        # Drain all queued messages
        while true
            msg_ptr = ccall(
                (:dbus_connection_pop_message, libdbus),
                Ptr{Cvoid},
                (Ptr{Cvoid},),
                conn.ptr,
            )
            msg_ptr == C_NULL && break
            msg = DBusMessage(msg_ptr; owns = true)
            _handle_message(svc, msg)
        end
    end
    return nothing
end

"""
    stop(svc::DBusService)

Signal the service dispatch loop to exit.
"""
function stop(svc::DBusService)
    put!(svc.stop_channel, true)
    return nothing
end

function _handle_message(svc::DBusService, msg::DBusMessage)
    message_type(msg) == DBUS_MESSAGE_TYPE_METHOD_CALL || return nothing

    path = object_path(msg)
    iface = interface(msg)
    meth = member(msg)

    path === nothing && return nothing
    iface === nothing && return nothing
    meth === nothing && return nothing

    path_dict = get(svc.handlers, path, nothing)
    path_dict === nothing && return nothing
    iface_dict = get(path_dict, iface, nothing)
    iface_dict === nothing && return nothing
    handler = get(iface_dict, meth, nothing)
    handler === nothing && return nothing

    try
        args = read_args(msg)
        handler(svc.conn, msg, args)
    catch ex
        try
            send_error(
                svc.conn,
                msg,
                "org.freedesktop.DBus.Error.Failed",
                sprint(showerror, ex),
            )
        catch
            # If we can't even send the error, just drop it
        end
    end

    return nothing
end
