# ──────────────────────────────────────────────────────────────────
# High-level call API: call_method, send_message, send_reply, send_error
# ──────────────────────────────────────────────────────────────────

"""
    call_method(conn, dest, path, iface, method; args=(), timeout_ms=30_000)

Perform a synchronous D-Bus method call. Returns `Vector{Any}` of reply
arguments (empty if the method has no return values). Throws `DBusError`
if the call fails or returns an error reply.
"""
function call_method(
    conn::DBusConnection,
    dest::AbstractString,
    path::AbstractString,
    iface::AbstractString,
    method::AbstractString;
    args = (),
    timeout_ms::Integer = 30_000,
)
    _check_conn(conn)
    msg = DBusMessage(dest, path, iface, method)
    if !isempty(args)
        append_args!(msg, args...)
    end
    reply_ptr = with_dbus_error() do err
        ccall(
            (:dbus_connection_send_with_reply_and_block, libdbus),
            Ptr{Cvoid},
            (Ptr{Cvoid}, Ptr{Cvoid}, Cint, Ptr{Cvoid}),
            conn.ptr,
            msg.ptr,
            Cint(timeout_ms),
            err,
        )
    end
    reply = DBusMessage(reply_ptr; owns = true)
    return read_args(reply)
end

"""
    send_message(conn, msg) -> UInt32

Send a message without waiting for a reply. Returns the message serial
number. Flushes the connection after sending.
"""
function send_message(conn::DBusConnection, msg::DBusMessage)
    _check_conn(conn)
    _check_msg(msg)
    serial = Ref{Cuint}(0)
    ret = ccall(
        (:dbus_connection_send, libdbus),
        Cuint,
        (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cuint}),
        conn.ptr,
        msg.ptr,
        serial,
    )
    ret == 0 && error("dbus_connection_send failed (out of memory)")
    flush(conn)
    return serial[]
end

"""
    send_reply(conn, call_msg; args=())

Send a method-return reply to `call_msg`. Optionally append `args` to the
reply body.
"""
function send_reply(conn::DBusConnection, call_msg::DBusMessage; args = ())
    _check_msg(call_msg)
    reply_ptr = ccall(
        (:dbus_message_new_method_return, libdbus),
        Ptr{Cvoid},
        (Ptr{Cvoid},),
        call_msg.ptr,
    )
    reply = DBusMessage(reply_ptr; owns = true)
    if !isempty(args)
        append_args!(reply, args...)
    end
    send_message(conn, reply)
    return nothing
end

"""
    send_error(conn, call_msg, error_name, error_message)

Send an error reply to `call_msg`.
"""
function send_error(
    conn::DBusConnection,
    call_msg::DBusMessage,
    error_name::AbstractString,
    error_message::AbstractString,
)
    _check_msg(call_msg)
    err_ptr = ccall(
        (:dbus_message_new_error, libdbus),
        Ptr{Cvoid},
        (Ptr{Cvoid}, Cstring, Cstring),
        call_msg.ptr,
        error_name,
        error_message,
    )
    err_msg = DBusMessage(err_ptr; owns = true)
    send_message(conn, err_msg)
    return nothing
end
