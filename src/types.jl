# ──────────────────────────────────────────────────────────────────
# D-Bus C constants and Julia ↔ D-Bus type mappings
# ──────────────────────────────────────────────────────────────────

# Bus types (DBusBusType enum — dbus-shared.h)
const DBUS_BUS_SESSION = Cint(0)
const DBUS_BUS_SYSTEM = Cint(1)
const DBUS_BUS_STARTER = Cint(2)

# Message types (dbus-protocol.h)
const DBUS_MESSAGE_TYPE_INVALID = Cint(0)
const DBUS_MESSAGE_TYPE_METHOD_CALL = Cint(1)
const DBUS_MESSAGE_TYPE_METHOD_RETURN = Cint(2)
const DBUS_MESSAGE_TYPE_ERROR = Cint(3)
const DBUS_MESSAGE_TYPE_SIGNAL = Cint(4)

# Type codes (ASCII values — dbus-protocol.h)
const DBUS_TYPE_INVALID = Cint(0)
const DBUS_TYPE_BYTE = Cint('y')
const DBUS_TYPE_BOOLEAN = Cint('b')
const DBUS_TYPE_INT16 = Cint('n')
const DBUS_TYPE_UINT16 = Cint('q')
const DBUS_TYPE_INT32 = Cint('i')
const DBUS_TYPE_UINT32 = Cint('u')
const DBUS_TYPE_INT64 = Cint('x')
const DBUS_TYPE_UINT64 = Cint('t')
const DBUS_TYPE_DOUBLE = Cint('d')
const DBUS_TYPE_STRING = Cint('s')
const DBUS_TYPE_OBJECT_PATH = Cint('o')
const DBUS_TYPE_SIGNATURE = Cint('g')
const DBUS_TYPE_UNIX_FD = Cint('h')
const DBUS_TYPE_ARRAY = Cint('a')
const DBUS_TYPE_VARIANT = Cint('v')
const DBUS_TYPE_STRUCT = Cint('r')
const DBUS_TYPE_DICT_ENTRY = Cint('e')

# Container delimiters
const DBUS_STRUCT_BEGIN_CHAR = Cint('(')
const DBUS_STRUCT_END_CHAR = Cint(')')
const DBUS_DICT_ENTRY_BEGIN_CHAR = Cint('{')
const DBUS_DICT_ENTRY_END_CHAR = Cint('}')

# Name request flags (dbus-shared.h)
const DBUS_NAME_FLAG_ALLOW_REPLACEMENT = Cuint(0x1)
const DBUS_NAME_FLAG_REPLACE_EXISTING = Cuint(0x2)
const DBUS_NAME_FLAG_DO_NOT_QUEUE = Cuint(0x4)

# Name request reply codes
const DBUS_REQUEST_NAME_REPLY_PRIMARY_OWNER = Cint(1)
const DBUS_REQUEST_NAME_REPLY_IN_QUEUE = Cint(2)
const DBUS_REQUEST_NAME_REPLY_EXISTS = Cint(3)
const DBUS_REQUEST_NAME_REPLY_ALREADY_OWNER = Cint(4)

# ──────────────────────────────────────────────────────────────────
# Struct sizes (64-bit Linux; over-allocated for safety)
# ──────────────────────────────────────────────────────────────────
const DBUS_ERROR_STRUCT_SIZE = 32
const DBUS_MESSAGE_ITER_SIZE = 128

# ──────────────────────────────────────────────────────────────────
# Julia type → D-Bus type code
# ──────────────────────────────────────────────────────────────────
const JULIA_TO_DBUS = Dict{DataType,Cint}(
    UInt8 => DBUS_TYPE_BYTE,
    Bool => DBUS_TYPE_BOOLEAN,
    Int16 => DBUS_TYPE_INT16,
    UInt16 => DBUS_TYPE_UINT16,
    Int32 => DBUS_TYPE_INT32,
    UInt32 => DBUS_TYPE_UINT32,
    Int64 => DBUS_TYPE_INT64,
    UInt64 => DBUS_TYPE_UINT64,
    Float64 => DBUS_TYPE_DOUBLE,
    String => DBUS_TYPE_STRING,
)

# D-Bus type code → Julia type
const DBUS_TO_JULIA = Dict{Cint,DataType}(
    DBUS_TYPE_BYTE => UInt8,
    DBUS_TYPE_BOOLEAN => Bool,
    DBUS_TYPE_INT16 => Int16,
    DBUS_TYPE_UINT16 => UInt16,
    DBUS_TYPE_INT32 => Int32,
    DBUS_TYPE_UINT32 => UInt32,
    DBUS_TYPE_INT64 => Int64,
    DBUS_TYPE_UINT64 => UInt64,
    DBUS_TYPE_DOUBLE => Float64,
    DBUS_TYPE_STRING => String,
    DBUS_TYPE_OBJECT_PATH => String,
    DBUS_TYPE_SIGNATURE => String,
)

# Julia type → D-Bus signature character
const JULIA_TO_DBUS_SIG = Dict{DataType,String}(
    UInt8 => "y",
    Bool => "b",
    Int16 => "n",
    UInt16 => "q",
    Int32 => "i",
    UInt32 => "u",
    Int64 => "x",
    UInt64 => "t",
    Float64 => "d",
    String => "s",
)

# ──────────────────────────────────────────────────────────────────
# Helper functions
# ──────────────────────────────────────────────────────────────────

"""
    dbus_type_code(::Type{T}) -> Cint

Return the D-Bus type code for a Julia type.
"""
dbus_type_code(::Type{UInt8}) = DBUS_TYPE_BYTE
dbus_type_code(::Type{Bool}) = DBUS_TYPE_BOOLEAN
dbus_type_code(::Type{Int16}) = DBUS_TYPE_INT16
dbus_type_code(::Type{UInt16}) = DBUS_TYPE_UINT16
dbus_type_code(::Type{Int32}) = DBUS_TYPE_INT32
dbus_type_code(::Type{UInt32}) = DBUS_TYPE_UINT32
dbus_type_code(::Type{Int64}) = DBUS_TYPE_INT64
dbus_type_code(::Type{UInt64}) = DBUS_TYPE_UINT64
dbus_type_code(::Type{Float64}) = DBUS_TYPE_DOUBLE
dbus_type_code(::Type{String}) = DBUS_TYPE_STRING

"""
    dbus_signature(::Type{T}) -> String

Return the D-Bus type signature string for a Julia type.
"""
dbus_signature(::Type{UInt8}) = "y"
dbus_signature(::Type{Bool}) = "b"
dbus_signature(::Type{Int16}) = "n"
dbus_signature(::Type{UInt16}) = "q"
dbus_signature(::Type{Int32}) = "i"
dbus_signature(::Type{UInt32}) = "u"
dbus_signature(::Type{Int64}) = "x"
dbus_signature(::Type{UInt64}) = "t"
dbus_signature(::Type{Float64}) = "d"
dbus_signature(::Type{String}) = "s"
dbus_signature(::Type{Vector{T}}) where {T} = "a" * dbus_signature(T)
