# ──────────────────────────────────────────────────────────────────
# DBusError exception and with_dbus_error helper
# ──────────────────────────────────────────────────────────────────

"""
    DBusError <: Exception

Exception thrown when a D-Bus operation fails. Carries the error `name`
(e.g. `"org.freedesktop.DBus.Error.ServiceUnknown"`) and a human-readable
`message`.
"""
struct DBusError <: Exception
    name::String
    message::String
end

function Base.showerror(io::IO, e::DBusError)
    return print(io, "DBusError: ", e.name, ": ", e.message)
end

"""
    with_dbus_error(f) -> result

Allocate a C `DBusError` on the stack, call `f(err_ptr)`, and check whether
the error was set. If so, extract the name and message, free the C error,
and throw a Julia `DBusError`. Otherwise return the result of `f`.
"""
function with_dbus_error(f)
    buf = zeros(UInt8, DBUS_ERROR_STRUCT_SIZE)
    GC.@preserve buf begin
        err_ptr = pointer(buf)
        ccall((:dbus_error_init, libdbus), Cvoid, (Ptr{Cvoid},), err_ptr)

        result = f(err_ptr)

        is_set = ccall((:dbus_error_is_set, libdbus), Cuint, (Ptr{Cvoid},), err_ptr)
        if is_set != 0
            # DBusError layout (64-bit): name::Ptr{Cchar} at 0, message::Ptr{Cchar} at 8
            name_ptr = unsafe_load(Ptr{Ptr{Cchar}}(err_ptr))
            msg_ptr = unsafe_load(Ptr{Ptr{Cchar}}(err_ptr + sizeof(Ptr{Cvoid})))
            name = name_ptr != C_NULL ? unsafe_string(name_ptr) : ""
            msg = msg_ptr != C_NULL ? unsafe_string(msg_ptr) : ""
            ccall((:dbus_error_free, libdbus), Cvoid, (Ptr{Cvoid},), err_ptr)
            throw(DBusError(name, msg))
        end

        return result
    end
end
