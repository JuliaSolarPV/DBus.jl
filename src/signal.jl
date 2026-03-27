# ──────────────────────────────────────────────────────────────────
# Signal emission
# ──────────────────────────────────────────────────────────────────

"""
    send_signal(conn, path, iface, name; args=())

Emit a D-Bus signal from object `path` on interface `iface` with signal
`name`. Optionally attach `args` to the signal body.
"""
function send_signal(
    conn::DBusConnection,
    path::AbstractString,
    iface::AbstractString,
    name::AbstractString;
    args = (),
)
    msg = DBusMessage(Val(:signal), path, iface, name)
    if !isempty(args)
        append_args!(msg, args...)
    end
    send_message(conn, msg)
    return nothing
end
