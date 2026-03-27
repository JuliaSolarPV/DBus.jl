# DBus.jl Demo
#
# Run with:  julia --project=. examples/demo.jl
#
# Requires a running D-Bus session bus (standard on most Linux desktops).

using DBus

# ── 1. Connect to the session bus ─────────────────────────────────

println("=== Connecting to session bus ===")
conn = DBusConnection(DBUS_BUS_SESSION)
println("Connected as: ", unique_name(conn))

# ── 2. List all bus names ─────────────────────────────────────────

println("\n=== Listing bus names ===")
result = call_method(
    conn,
    "org.freedesktop.DBus",
    "/org/freedesktop/DBus",
    "org.freedesktop.DBus",
    "ListNames",
)
bus_names = result[1]
println("Found $(length(bus_names)) names on the bus:")
for name in bus_names
    println("  ", name)
end

# ── 3. Get the bus ID ─────────────────────────────────────────────

println("\n=== Bus ID ===")
bus_id = call_method(
    conn,
    "org.freedesktop.DBus",
    "/org/freedesktop/DBus",
    "org.freedesktop.DBus",
    "GetId",
)
println("Bus ID: ", bus_id[1])

# ── 4. Ping the bus daemon ────────────────────────────────────────

println("\n=== Ping ===")
call_method(
    conn,
    "org.freedesktop.DBus",
    "/org/freedesktop/DBus",
    "org.freedesktop.DBus.Peer",
    "Ping",
)
println("Ping successful!")

# ── 5. Check if a name exists ────────────────────────────────────

println("\n=== Name lookup ===")
name_to_check = "org.freedesktop.DBus"
has_owner = call_method(
    conn,
    "org.freedesktop.DBus",
    "/org/freedesktop/DBus",
    "org.freedesktop.DBus",
    "NameHasOwner";
    args = (name_to_check,),
)
println("\"$name_to_check\" has owner: ", has_owner[1])

# ── 6. Send a signal ─────────────────────────────────────────────

println("\n=== Sending a signal ===")
send_signal(
    conn,
    "/com/example/demo",
    "com.example.Demo",
    "Heartbeat";
    args = (Int32(42), "hello from DBus.jl"),
)
println("Signal sent!")

# ── 7. Build and inspect a message manually ───────────────────────

println("\n=== Manual message construction ===")
msg = DBusMessage(
    "org.freedesktop.DBus",
    "/org/freedesktop/DBus",
    "org.freedesktop.DBus",
    "GetNameOwner",
)
println(
    "Message type:  ",
    message_type(msg) == DBUS_MESSAGE_TYPE_METHOD_CALL ? "METHOD_CALL" : "other",
)
println("Destination:   ", destination(msg))
println("Object path:   ", object_path(msg))
println("Interface:     ", interface(msg))
println("Member:        ", member(msg))

# Append an argument and send it
append_args!(msg, "org.freedesktop.DBus")
reply_ptr = DBus.with_dbus_error() do err
    ccall(
        (:dbus_connection_send_with_reply_and_block, DBus.libdbus),
        Ptr{Cvoid},
        (Ptr{Cvoid}, Ptr{Cvoid}, Cint, Ptr{Cvoid}),
        conn.ptr,
        msg.ptr,
        Cint(5000),
        err,
    )
end
reply = DBusMessage(reply_ptr; owns = true)
reply_args = read_args(reply)
println("Owner of org.freedesktop.DBus: ", reply_args[1])

# ── Done ──────────────────────────────────────────────────────────

close(conn)
println("\n=== Demo complete ===")
