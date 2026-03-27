# ──────────────────────────────────────────────────────────────────
# Argument serialisation (append) and deserialisation (read)
# via DBusMessageIter
# ──────────────────────────────────────────────────────────────────

_new_iter_buf() = zeros(UInt8, DBUS_MESSAGE_ITER_SIZE)
_iter_ptr(buf::Vector{UInt8}) = Ptr{Cvoid}(pointer(buf))

# ══════════════════════════════════════════════════════════════════
# Appending arguments
# ══════════════════════════════════════════════════════════════════

"""
    append_args!(msg::DBusMessage, args...)

Serialise `args` into the message body. Each argument is dispatched
to the appropriate D-Bus type based on its Julia type.
"""
function append_args!(msg::DBusMessage, args...)
    _check_msg(msg)
    isempty(args) && return nothing
    buf = _new_iter_buf()
    GC.@preserve buf begin
        ip = _iter_ptr(buf)
        ccall(
            (:dbus_message_iter_init_append, libdbus),
            Cvoid,
            (Ptr{Cvoid}, Ptr{Cvoid}),
            msg.ptr,
            ip,
        )
        for arg in args
            _append_arg!(ip, arg)
        end
    end
    return nothing
end

# ── Basic numeric types ───────────────────────────────────────────

const _BasicNumeric = Union{UInt8,Int16,UInt16,Int32,UInt32,Int64,UInt64,Float64}

function _append_arg!(ip::Ptr{Cvoid}, val::T) where {T<:_BasicNumeric}
    ref = Ref(val)
    ret = ccall(
        (:dbus_message_iter_append_basic, libdbus),
        Cuint,
        (Ptr{Cvoid}, Cint, Ptr{Cvoid}),
        ip,
        dbus_type_code(T),
        ref,
    )
    ret == 0 && error("dbus_message_iter_append_basic failed")
    return nothing
end

# ── Bool (widened to Cuint — dbus_bool_t is 4 bytes) ──────────────

function _append_arg!(ip::Ptr{Cvoid}, val::Bool)
    ref = Ref(Cuint(val))
    ret = ccall(
        (:dbus_message_iter_append_basic, libdbus),
        Cuint,
        (Ptr{Cvoid}, Cint, Ptr{Cvoid}),
        ip,
        DBUS_TYPE_BOOLEAN,
        ref,
    )
    ret == 0 && error("dbus_message_iter_append_basic failed")
    return nothing
end

# ── String (append_basic expects const char**) ────────────────────

function _append_arg!(ip::Ptr{Cvoid}, val::AbstractString)
    s = String(val)
    # dbus_message_iter_append_basic for strings expects const char**
    GC.@preserve s begin
        str_ptr = pointer(s)
        ref = Ref(str_ptr)
        ret = ccall(
            (:dbus_message_iter_append_basic, libdbus),
            Cuint,
            (Ptr{Cvoid}, Cint, Ptr{Cvoid}),
            ip,
            DBUS_TYPE_STRING,
            ref,
        )
        ret == 0 && error("dbus_message_iter_append_basic failed")
    end
    return nothing
end

# ── Vector{T} → D-Bus array ──────────────────────────────────────

function _append_arg!(ip::Ptr{Cvoid}, val::Vector{T}) where {T}
    sub_buf = _new_iter_buf()
    sig = dbus_signature(T)
    GC.@preserve sub_buf sig begin
        sub_ip = _iter_ptr(sub_buf)
        ret = ccall(
            (:dbus_message_iter_open_container, libdbus),
            Cuint,
            (Ptr{Cvoid}, Cint, Cstring, Ptr{Cvoid}),
            ip,
            DBUS_TYPE_ARRAY,
            sig,
            sub_ip,
        )
        ret == 0 && error("dbus_message_iter_open_container failed")
        for item in val
            _append_arg!(sub_ip, item)
        end
        ret = ccall(
            (:dbus_message_iter_close_container, libdbus),
            Cuint,
            (Ptr{Cvoid}, Ptr{Cvoid}),
            ip,
            sub_ip,
        )
        ret == 0 && error("dbus_message_iter_close_container failed")
    end
    return nothing
end

# ── DBusVariant{T} → D-Bus variant ────────────────────────────────

function _append_arg!(ip::Ptr{Cvoid}, val::DBusVariant{T}) where {T}
    sub_buf = _new_iter_buf()
    sig = dbus_signature(T)
    GC.@preserve sub_buf sig begin
        sub_ip = _iter_ptr(sub_buf)
        ret = ccall(
            (:dbus_message_iter_open_container, libdbus),
            Cuint,
            (Ptr{Cvoid}, Cint, Cstring, Ptr{Cvoid}),
            ip,
            DBUS_TYPE_VARIANT,
            sig,
            sub_ip,
        )
        ret == 0 && error("dbus_message_iter_open_container failed")
        _append_arg!(sub_ip, val.value)
        ret = ccall(
            (:dbus_message_iter_close_container, libdbus),
            Cuint,
            (Ptr{Cvoid}, Ptr{Cvoid}),
            ip,
            sub_ip,
        )
        ret == 0 && error("dbus_message_iter_close_container failed")
    end
    return nothing
end

# ── Dict{K,V} → D-Bus array of dict entries ──────────────────────

function _append_dict_entry!(ip::Ptr{Cvoid}, key, value)
    sub_buf = _new_iter_buf()
    GC.@preserve sub_buf begin
        sub_ip = _iter_ptr(sub_buf)
        ret = ccall(
            (:dbus_message_iter_open_container, libdbus),
            Cuint,
            (Ptr{Cvoid}, Cint, Ptr{Cvoid}, Ptr{Cvoid}),
            ip,
            DBUS_TYPE_DICT_ENTRY,
            C_NULL,
            sub_ip,
        )
        ret == 0 && error("dbus_message_iter_open_container failed")
        _append_arg!(sub_ip, key)
        _append_arg!(sub_ip, value)
        ret = ccall(
            (:dbus_message_iter_close_container, libdbus),
            Cuint,
            (Ptr{Cvoid}, Ptr{Cvoid}),
            ip,
            sub_ip,
        )
        ret == 0 && error("dbus_message_iter_close_container failed")
    end
    return nothing
end

function _append_arg!(ip::Ptr{Cvoid}, val::Dict{K,V}) where {K,V}
    sub_buf = _new_iter_buf()
    entry_sig = _dict_entry_sig(K, V)
    GC.@preserve sub_buf entry_sig begin
        sub_ip = _iter_ptr(sub_buf)
        ret = ccall(
            (:dbus_message_iter_open_container, libdbus),
            Cuint,
            (Ptr{Cvoid}, Cint, Cstring, Ptr{Cvoid}),
            ip,
            DBUS_TYPE_ARRAY,
            entry_sig,
            sub_ip,
        )
        ret == 0 && error("dbus_message_iter_open_container failed")
        for (k, v) in val
            _append_dict_entry!(sub_ip, k, v)
        end
        ret = ccall(
            (:dbus_message_iter_close_container, libdbus),
            Cuint,
            (Ptr{Cvoid}, Ptr{Cvoid}),
            ip,
            sub_ip,
        )
        ret == 0 && error("dbus_message_iter_close_container failed")
    end
    return nothing
end

# ══════════════════════════════════════════════════════════════════
# Reading arguments
# ══════════════════════════════════════════════════════════════════

"""
    read_args(msg::DBusMessage) -> Vector{Any}

Deserialise all arguments from the message body.
"""
function read_args(msg::DBusMessage)
    _check_msg(msg)
    result = Any[]
    buf = _new_iter_buf()
    GC.@preserve buf begin
        ip = _iter_ptr(buf)
        has_args = ccall(
            (:dbus_message_iter_init, libdbus),
            Cuint,
            (Ptr{Cvoid}, Ptr{Cvoid}),
            msg.ptr,
            ip,
        )
        has_args == 0 && return result
        while true
            push!(result, _read_arg(ip))
            has_next = ccall((:dbus_message_iter_next, libdbus), Cuint, (Ptr{Cvoid},), ip)
            has_next == 0 && break
        end
    end
    return result
end

function _read_arg(ip::Ptr{Cvoid})
    type_code = ccall((:dbus_message_iter_get_arg_type, libdbus), Cint, (Ptr{Cvoid},), ip)

    # Basic numeric types
    if type_code == DBUS_TYPE_BYTE
        return _read_basic(ip, UInt8)
    elseif type_code == DBUS_TYPE_INT16
        return _read_basic(ip, Int16)
    elseif type_code == DBUS_TYPE_UINT16
        return _read_basic(ip, UInt16)
    elseif type_code == DBUS_TYPE_INT32
        return _read_basic(ip, Int32)
    elseif type_code == DBUS_TYPE_UINT32
        return _read_basic(ip, UInt32)
    elseif type_code == DBUS_TYPE_INT64
        return _read_basic(ip, Int64)
    elseif type_code == DBUS_TYPE_UINT64
        return _read_basic(ip, UInt64)
    elseif type_code == DBUS_TYPE_DOUBLE
        return _read_basic(ip, Float64)

        # Boolean — read as Cuint, convert
    elseif type_code == DBUS_TYPE_BOOLEAN
        return _read_basic(ip, Cuint) != 0

        # String-like types
    elseif type_code in (DBUS_TYPE_STRING, DBUS_TYPE_OBJECT_PATH, DBUS_TYPE_SIGNATURE)
        return _read_string(ip)

        # Array
    elseif type_code == DBUS_TYPE_ARRAY
        return _read_array(ip)

        # Variant
    elseif type_code == DBUS_TYPE_VARIANT
        return _read_variant(ip)

        # Struct
    elseif type_code == DBUS_TYPE_STRUCT
        return _read_struct(ip)

    else
        error("Unsupported D-Bus type code: $(Char(type_code)) ($type_code)")
    end
end

function _read_basic(ip::Ptr{Cvoid}, ::Type{T}) where {T}
    ref = Ref{T}(zero(T))
    ccall((:dbus_message_iter_get_basic, libdbus), Cvoid, (Ptr{Cvoid}, Ptr{Cvoid}), ip, ref)
    return ref[]
end

function _read_string(ip::Ptr{Cvoid})
    ref = Ref{Ptr{Cchar}}(C_NULL)
    ccall((:dbus_message_iter_get_basic, libdbus), Cvoid, (Ptr{Cvoid}, Ptr{Cvoid}), ip, ref)
    return ref[] == C_NULL ? "" : unsafe_string(ref[])
end

function _read_array(ip::Ptr{Cvoid})
    sub_buf = _new_iter_buf()
    GC.@preserve sub_buf begin
        sub_ip = _iter_ptr(sub_buf)
        ccall(
            (:dbus_message_iter_recurse, libdbus),
            Cvoid,
            (Ptr{Cvoid}, Ptr{Cvoid}),
            ip,
            sub_ip,
        )
        elem_type =
            ccall((:dbus_message_iter_get_arg_type, libdbus), Cint, (Ptr{Cvoid},), sub_ip)
        elem_type == DBUS_TYPE_INVALID && return Any[]

        # Dict: array of dict entries → Dict{Any,Any}
        if elem_type == DBUS_TYPE_DICT_ENTRY
            dict = Dict{Any,Any}()
            while true
                k, v = _read_dict_entry(sub_ip)
                dict[k] = v
                has_next =
                    ccall((:dbus_message_iter_next, libdbus), Cuint, (Ptr{Cvoid},), sub_ip)
                has_next == 0 && break
            end
            return dict
        end

        # Regular array
        result = Any[]
        while true
            push!(result, _read_arg(sub_ip))
            has_next =
                ccall((:dbus_message_iter_next, libdbus), Cuint, (Ptr{Cvoid},), sub_ip)
            has_next == 0 && break
        end
        return result
    end
end

function _read_dict_entry(ip::Ptr{Cvoid})
    sub_buf = _new_iter_buf()
    GC.@preserve sub_buf begin
        sub_ip = _iter_ptr(sub_buf)
        ccall(
            (:dbus_message_iter_recurse, libdbus),
            Cvoid,
            (Ptr{Cvoid}, Ptr{Cvoid}),
            ip,
            sub_ip,
        )
        key = _read_arg(sub_ip)
        ccall((:dbus_message_iter_next, libdbus), Cuint, (Ptr{Cvoid},), sub_ip)
        value = _read_arg(sub_ip)
        return (key, value)
    end
end

function _read_variant(ip::Ptr{Cvoid})
    sub_buf = _new_iter_buf()
    GC.@preserve sub_buf begin
        sub_ip = _iter_ptr(sub_buf)
        ccall(
            (:dbus_message_iter_recurse, libdbus),
            Cvoid,
            (Ptr{Cvoid}, Ptr{Cvoid}),
            ip,
            sub_ip,
        )
        return DBusVariant(_read_arg(sub_ip))
    end
end

function _read_struct(ip::Ptr{Cvoid})
    sub_buf = _new_iter_buf()
    fields = Any[]
    GC.@preserve sub_buf begin
        sub_ip = _iter_ptr(sub_buf)
        ccall(
            (:dbus_message_iter_recurse, libdbus),
            Cvoid,
            (Ptr{Cvoid}, Ptr{Cvoid}),
            ip,
            sub_ip,
        )
        elem_type =
            ccall((:dbus_message_iter_get_arg_type, libdbus), Cint, (Ptr{Cvoid},), sub_ip)
        elem_type == DBUS_TYPE_INVALID && return ()
        while true
            push!(fields, _read_arg(sub_ip))
            has_next =
                ccall((:dbus_message_iter_next, libdbus), Cuint, (Ptr{Cvoid},), sub_ip)
            has_next == 0 && break
        end
    end
    return Tuple(fields)
end
