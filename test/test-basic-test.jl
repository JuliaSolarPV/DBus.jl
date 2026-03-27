@testsnippet DBusSetup begin
    using DBus
end

# ──────────────────────────────────────────────────────────────────
# Types and constants
# ──────────────────────────────────────────────────────────────────

@testitem "Bus type constants" tags = [:unit, :fast] setup = [DBusSetup] begin
    @test DBUS_BUS_SESSION == 0
    @test DBUS_BUS_SYSTEM == 1
    @test DBUS_BUS_STARTER == 2
end

@testitem "Message type constants" tags = [:unit, :fast] setup = [DBusSetup] begin
    @test DBUS_MESSAGE_TYPE_METHOD_CALL == 1
    @test DBUS_MESSAGE_TYPE_METHOD_RETURN == 2
    @test DBUS_MESSAGE_TYPE_ERROR == 3
    @test DBUS_MESSAGE_TYPE_SIGNAL == 4
end

@testitem "Type code constants" tags = [:unit, :fast] setup = [DBusSetup] begin
    @test DBus.DBUS_TYPE_BYTE == Int('y')
    @test DBus.DBUS_TYPE_BOOLEAN == Int('b')
    @test DBus.DBUS_TYPE_INT32 == Int('i')
    @test DBus.DBUS_TYPE_STRING == Int('s')
    @test DBus.DBUS_TYPE_ARRAY == Int('a')
    @test DBus.DBUS_TYPE_VARIANT == Int('v')
end

@testitem "dbus_type_code dispatch" tags = [:unit, :fast] setup = [DBusSetup] begin
    @test DBus.dbus_type_code(UInt8) == DBus.DBUS_TYPE_BYTE
    @test DBus.dbus_type_code(Bool) == DBus.DBUS_TYPE_BOOLEAN
    @test DBus.dbus_type_code(Int32) == DBus.DBUS_TYPE_INT32
    @test DBus.dbus_type_code(String) == DBus.DBUS_TYPE_STRING
    @test DBus.dbus_type_code(Float64) == DBus.DBUS_TYPE_DOUBLE
end

@testitem "dbus_signature" tags = [:unit, :fast] setup = [DBusSetup] begin
    @test DBus.dbus_signature(Int32) == "i"
    @test DBus.dbus_signature(String) == "s"
    @test DBus.dbus_signature(Bool) == "b"
    @test DBus.dbus_signature(Vector{Int32}) == "ai"
    @test DBus.dbus_signature(Vector{String}) == "as"
end

# ──────────────────────────────────────────────────────────────────
# Error handling
# ──────────────────────────────────────────────────────────────────

@testitem "DBusError display" tags = [:unit, :fast] setup = [DBusSetup] begin
    err = DBusError("org.example.Error", "something broke")
    buf = IOBuffer()
    showerror(buf, err)
    s = String(take!(buf))
    @test contains(s, "org.example.Error")
    @test contains(s, "something broke")
end

@testitem "with_dbus_error no-error path" tags = [:unit, :fast] setup = [DBusSetup] begin
    # with_dbus_error should return the result when no error is set
    result = DBus.with_dbus_error() do err_ptr
        42
    end
    @test result == 42
end

# ──────────────────────────────────────────────────────────────────
# Message construction and accessors
# ──────────────────────────────────────────────────────────────────

@testitem "Method call message" tags = [:unit, :fast] setup = [DBusSetup] begin
    msg =
        DBusMessage("org.example.Dest", "/org/example/Path", "org.example.Iface", "DoStuff")
    @test destination(msg) == "org.example.Dest"
    @test object_path(msg) == "/org/example/Path"
    @test interface(msg) == "org.example.Iface"
    @test member(msg) == "DoStuff"
    @test message_type(msg) == DBUS_MESSAGE_TYPE_METHOD_CALL
end

@testitem "Signal message" tags = [:unit, :fast] setup = [DBusSetup] begin
    msg = DBusMessage(
        Val(:signal),
        "/org/example/Path",
        "org.example.Iface",
        "SomethingHappened",
    )
    @test object_path(msg) == "/org/example/Path"
    @test interface(msg) == "org.example.Iface"
    @test member(msg) == "SomethingHappened"
    @test message_type(msg) == DBUS_MESSAGE_TYPE_SIGNAL
end

# ──────────────────────────────────────────────────────────────────
# Serialisation round-trips
# ──────────────────────────────────────────────────────────────────

@testitem "Round-trip: Int32" tags = [:unit, :fast] setup = [DBusSetup] begin
    msg = DBusMessage("org.test.X", "/org/test/X", "org.test.X", "Method")
    append_args!(msg, Int32(42))
    args = read_args(msg)
    @test length(args) == 1
    @test args[1] === Int32(42)
end

@testitem "Round-trip: multiple types" tags = [:unit, :fast] setup = [DBusSetup] begin
    msg = DBusMessage("org.test.X", "/org/test/X", "org.test.X", "Method")
    append_args!(msg, UInt8(255), Int16(-1), Int64(2^40), Float64(3.14), "hello")
    args = read_args(msg)
    @test args[1] === UInt8(255)
    @test args[2] === Int16(-1)
    @test args[3] === Int64(2^40)
    @test args[4] ≈ 3.14
    @test args[5] == "hello"
end

@testitem "Round-trip: Bool" tags = [:unit, :fast] setup = [DBusSetup] begin
    msg = DBusMessage("org.test.X", "/org/test/X", "org.test.X", "Method")
    append_args!(msg, true, false)
    args = read_args(msg)
    @test args[1] === true
    @test args[2] === false
end

@testitem "Round-trip: String" tags = [:unit, :fast] setup = [DBusSetup] begin
    msg = DBusMessage("org.test.X", "/org/test/X", "org.test.X", "Method")
    append_args!(msg, "hello world", "")
    args = read_args(msg)
    @test args[1] == "hello world"
    @test args[2] == ""
end

@testitem "Round-trip: Vector{Int32}" tags = [:unit, :fast] setup = [DBusSetup] begin
    msg = DBusMessage("org.test.X", "/org/test/X", "org.test.X", "Method")
    append_args!(msg, Int32[1, 2, 3])
    args = read_args(msg)
    @test length(args) == 1
    arr = args[1]
    @test length(arr) == 3
    @test arr[1] === Int32(1)
    @test arr[2] === Int32(2)
    @test arr[3] === Int32(3)
end

@testitem "Round-trip: Vector{String}" tags = [:unit, :fast] setup = [DBusSetup] begin
    msg = DBusMessage("org.test.X", "/org/test/X", "org.test.X", "Method")
    append_args!(msg, ["foo", "bar", "baz"])
    args = read_args(msg)
    @test length(args) == 1
    @test args[1] == Any["foo", "bar", "baz"]
end

@testitem "Round-trip: empty Vector" tags = [:unit, :fast] setup = [DBusSetup] begin
    msg = DBusMessage("org.test.X", "/org/test/X", "org.test.X", "Method")
    append_args!(msg, Int32[])
    args = read_args(msg)
    @test length(args) == 1
    @test isempty(args[1])
end

@testitem "Round-trip: no args" tags = [:unit, :fast] setup = [DBusSetup] begin
    msg = DBusMessage("org.test.X", "/org/test/X", "org.test.X", "Method")
    args = read_args(msg)
    @test isempty(args)
end

@testitem "Round-trip: UInt types" tags = [:unit, :fast] setup = [DBusSetup] begin
    msg = DBusMessage("org.test.X", "/org/test/X", "org.test.X", "Method")
    append_args!(msg, UInt16(1000), UInt32(100_000), UInt64(10_000_000_000))
    args = read_args(msg)
    @test args[1] === UInt16(1000)
    @test args[2] === UInt32(100_000)
    @test args[3] === UInt64(10_000_000_000)
end

# ──────────────────────────────────────────────────────────────────
# Integration tests (require a running session bus)
# ──────────────────────────────────────────────────────────────────

@testitem "Session bus connection" tags = [:integration] setup = [DBusSetup] begin
    conn = DBusConnection(DBUS_BUS_SESSION)
    @test isopen(conn)
    name = unique_name(conn)
    @test startswith(name, ":")
    close(conn)
    @test !isopen(conn)
end

@testitem "call_method: ListNames" tags = [:integration] setup = [DBusSetup] begin
    conn = DBusConnection(DBUS_BUS_SESSION)
    result = call_method(
        conn,
        "org.freedesktop.DBus",
        "/org/freedesktop/DBus",
        "org.freedesktop.DBus",
        "ListNames",
    )
    @test length(result) == 1
    names = result[1]
    @test isa(names, AbstractVector)
    @test "org.freedesktop.DBus" in names
    close(conn)
end

@testitem "call_method: Ping" tags = [:integration] setup = [DBusSetup] begin
    conn = DBusConnection(DBUS_BUS_SESSION)
    result = call_method(
        conn,
        "org.freedesktop.DBus",
        "/org/freedesktop/DBus",
        "org.freedesktop.DBus.Peer",
        "Ping",
    )
    @test isempty(result)
    close(conn)
end

@testitem "call_method: GetId" tags = [:integration] setup = [DBusSetup] begin
    conn = DBusConnection(DBUS_BUS_SESSION)
    result = call_method(
        conn,
        "org.freedesktop.DBus",
        "/org/freedesktop/DBus",
        "org.freedesktop.DBus",
        "GetId",
    )
    @test length(result) == 1
    @test isa(result[1], String)
    @test !isempty(result[1])
    close(conn)
end

@testitem "Service registration" tags = [:unit, :fast] setup = [DBusSetup] begin
    # Test that register_object populates the handler dict correctly.
    # Full round-trip requires multiple OS threads (Threads.@spawn) since
    # libdbus I/O calls block the calling thread.
    conn = DBusConnection(DBUS_BUS_SESSION)
    svc = DBusService(conn)
    handler = (c, m, a) -> nothing
    register_object(svc, "/org/test/Obj", "org.test.Iface", "Foo" => handler)
    @test svc.handlers["/org/test/Obj"]["org.test.Iface"]["Foo"] === handler
    stop(svc)
    close(conn)
end

@testitem "Service round-trip" tags = [:integration, :slow] setup = [DBusSetup] begin
    # This test requires Julia to be started with multiple threads
    # (e.g. --threads=2) because both the service loop and the client
    # call use blocking libdbus C calls.
    if Threads.nthreads() < 2
        @test_skip "requires --threads≥2"
    else
        svc_conn = DBusConnection(DBUS_BUS_SESSION)
        bus_name = "org.juliatest.DBusJl.pid$(getpid())"
        ret = request_name(svc_conn, bus_name)
        @test ret == DBus.DBUS_REQUEST_NAME_REPLY_PRIMARY_OWNER

        svc = DBusService(svc_conn)
        register_object(
            svc,
            "/org/juliatest/Obj",
            "org.juliatest.Iface",
            "Echo" => (conn, msg, args) -> send_reply(conn, msg; args = tuple(args...)),
        )

        # Run service on a separate OS thread
        svc_task = Threads.@spawn run(svc)
        sleep(0.2)

        client = DBusConnection(DBUS_BUS_SESSION)
        result = call_method(
            client,
            bus_name,
            "/org/juliatest/Obj",
            "org.juliatest.Iface",
            "Echo";
            args = (Int32(42), "hello"),
        )
        @test result[1] === Int32(42)
        @test result[2] == "hello"

        stop(svc)
        close(client)
        close(svc_conn)
    end
end

# ──────────────────────────────────────────────────────────────────
# Variant round-trips
# ──────────────────────────────────────────────────────────────────

@testitem "Round-trip: DBusVariant(Int32)" tags = [:unit, :fast] setup = [DBusSetup] begin
    msg = DBusMessage("org.test.X", "/org/test/X", "org.test.X", "Method")
    append_args!(msg, DBusVariant(Int32(42)))
    args = read_args(msg)
    @test length(args) == 1
    @test args[1] isa DBusVariant
    @test args[1].value === Int32(42)
end

@testitem "Round-trip: DBusVariant(String)" tags = [:unit, :fast] setup = [DBusSetup] begin
    msg = DBusMessage("org.test.X", "/org/test/X", "org.test.X", "Method")
    append_args!(msg, DBusVariant("hello"))
    args = read_args(msg)
    @test args[1] isa DBusVariant
    @test args[1].value == "hello"
end

@testitem "Round-trip: DBusVariant(Bool)" tags = [:unit, :fast] setup = [DBusSetup] begin
    msg = DBusMessage("org.test.X", "/org/test/X", "org.test.X", "Method")
    append_args!(msg, DBusVariant(true))
    args = read_args(msg)
    @test args[1] isa DBusVariant
    @test args[1].value === true
end

# ──────────────────────────────────────────────────────────────────
# Dict round-trips
# ──────────────────────────────────────────────────────────────────

@testitem "Round-trip: Dict{String,String}" tags = [:unit, :fast] setup = [DBusSetup] begin
    msg = DBusMessage("org.test.X", "/org/test/X", "org.test.X", "Method")
    append_args!(msg, Dict("a" => "alpha", "b" => "beta"))
    args = read_args(msg)
    @test length(args) == 1
    d = args[1]
    @test d isa Dict
    @test d["a"] == "alpha"
    @test d["b"] == "beta"
end

@testitem "Round-trip: Dict{String,DBusVariant} (Venus OS pattern)" tags = [:unit, :fast] setup =
    [DBusSetup] begin
    msg = DBusMessage("org.test.X", "/org/test/X", "org.test.X", "Method")
    append_args!(
        msg,
        Dict(
            "power" => DBusVariant(Int32(3500)),
            "name" => DBusVariant("EV Charger"),
            "connected" => DBusVariant(true),
        ),
    )
    args = read_args(msg)
    @test length(args) == 1
    d = args[1]
    @test d isa Dict
    @test d["power"].value === Int32(3500)
    @test d["name"].value == "EV Charger"
    @test d["connected"].value === true
end

@testitem "Round-trip: empty Dict" tags = [:unit, :fast] setup = [DBusSetup] begin
    msg = DBusMessage("org.test.X", "/org/test/X", "org.test.X", "Method")
    append_args!(msg, Dict{String,Int32}())
    args = read_args(msg)
    @test length(args) == 1
    # Empty dict comes back as empty array (no dict entries to detect)
    @test isempty(args[1])
end

@testitem "dbus_signature for variants and dicts" tags = [:unit, :fast] setup = [DBusSetup] begin
    @test DBus.dbus_signature(DBusVariant{Int32}) == "v"
    @test DBus.dbus_signature(Dict{String,Int32}) == "a{si}"
    @test DBus.dbus_signature(Dict{String,DBusVariant{Int32}}) == "a{sv}"
    @test DBus.dbus_signature(Pair{String,Int32}) == "{si}"
end
