# Venus OS EV Charger Driver Demo
#
# Mimics a Victron Energy Venus OS EV charger service, similar to:
#   https://github.com/mr-manuel/venus-os_dbus-mqtt-ev-charger
#
# Run with:  julia --threads=2 --project=. examples/evcharger.jl
#
# Then query it from another terminal:
#   busctl --user call com.victronenergy.evcharger.julia_demo \
#       /Ac/Power com.victronenergy.BusItem GetValue
#
#   busctl --user call com.victronenergy.evcharger.julia_demo \
#       / com.victronenergy.BusItem GetItems

using DBus

# ── Charger state ─────────────────────────────────────────────────
# Mutable state that the service exposes over D-Bus.

const CHARGER_STATE = Dict{String,Any}(
    # Management
    "/Mgmt/ProcessName" => "DBus.jl EV Charger Demo",
    "/Mgmt/ProcessVersion" => "0.1.0",
    "/Mgmt/Connection" => "local",
    # Device identity
    "/DeviceInstance" => Int32(0),
    "/ProductId" => Int32(0xFFFF),
    "/ProductName" => "Julia EV Charger",
    "/FirmwareVersion" => "0.1.0",
    "/Connected" => Int32(1),
    # AC measurements
    "/Ac/Power" => Float64(0.0),
    "/Ac/L1/Power" => Float64(0.0),
    "/Ac/L2/Power" => Float64(0.0),
    "/Ac/L3/Power" => Float64(0.0),
    "/Ac/Energy/Forward" => Float64(0.0),
    # Current
    "/Current" => Float64(0.0),
    "/MaxCurrent" => Float64(32.0),
    "/SetCurrent" => Float64(16.0),
    # Control
    "/Mode" => Int32(0),       # 0=Manual, 1=Auto, 2=Schedule
    "/Status" => Int32(0),     # 0=Disconnected, 1=Connected, 2=Charging, ...
    "/StartStop" => Int32(0),  # 0=Stop, 1=Start
    # Metadata
    "/ChargingTime" => Int32(0),
    "/Position" => Int32(0),   # 0=AC input, 1=AC output
)

# Text representation for display
function value_to_text(path::String, val)
    if path == "/Ac/Power" || occursin("/Power", path)
        return "$(round(val; digits=1)) W"
    elseif path == "/Ac/Energy/Forward"
        return "$(round(val; digits=2)) kWh"
    elseif occursin("Current", path)
        return "$(round(val; digits=1)) A"
    elseif path == "/Mode"
        return ["Manual", "Auto", "Schedule"][val + 1]
    elseif path == "/Status"
        return ["Disconnected", "Connected", "Charging", "Error"][val + 1]
    elseif path == "/ChargingTime"
        return "$(val) s"
    else
        return string(val)
    end
end

# ── Wrap a value as DBusVariant ───────────────────────────────────

function wrap_variant(val)
    if val isa String
        return DBusVariant(val)
    elseif val isa Float64
        return DBusVariant(val)
    elseif val isa Int32
        return DBusVariant(val)
    else
        return DBusVariant(string(val))
    end
end

# ── Handler functions ─────────────────────────────────────────────
# Each object path registers GetValue, GetText, and SetValue.

function handle_getvalue(conn, msg, args, path)
    val = get(CHARGER_STATE, path, nothing)
    if val === nothing
        send_error(conn, msg, "com.victronenergy.BusItem.NotFound", "Path not found: $path")
    else
        send_reply(conn, msg; args = (wrap_variant(val),))
    end
end

function handle_gettext(conn, msg, args, path)
    val = get(CHARGER_STATE, path, nothing)
    if val === nothing
        send_reply(conn, msg; args = ("",))
    else
        send_reply(conn, msg; args = (value_to_text(path, val),))
    end
end

function handle_setvalue(conn, msg, args, path)
    if isempty(args)
        send_error(conn, msg, "com.victronenergy.BusItem.Error", "Missing value argument")
        return
    end
    # Extract value from variant if wrapped
    val = args[1] isa DBusVariant ? args[1].value : args[1]
    CHARGER_STATE[path] = val
    println("  [SET] $path = $val")
    send_reply(conn, msg; args = (Int32(0),))  # 0 = success
end

function handle_getitems(conn, msg, args)
    # Return all items as a Dict{String, Variant}
    items = Dict{String,DBusVariant}()
    for (path, val) in CHARGER_STATE
        items[path] = wrap_variant(val)
    end
    send_reply(conn, msg; args = (items,))
end

# ── Register all paths ────────────────────────────────────────────

function register_charger_paths!(svc::DBusService)
    iface = "com.victronenergy.BusItem"

    # Register GetValue/GetText/SetValue for each path
    for path in keys(CHARGER_STATE)
        register_object(
            svc,
            path,
            iface,
            "GetValue" => (conn, msg, args) -> handle_getvalue(conn, msg, args, path),
            "GetText" => (conn, msg, args) -> handle_gettext(conn, msg, args, path),
            "SetValue" => (conn, msg, args) -> handle_setvalue(conn, msg, args, path),
        )
    end

    # Register GetItems on root
    register_object(svc, "/", iface, "GetItems" => handle_getitems)
end

# ── Simulate charging ─────────────────────────────────────────────

function simulate_charging!()
    if CHARGER_STATE["/StartStop"] == Int32(1) && CHARGER_STATE["/Status"] == Int32(2)
        current = Float64(CHARGER_STATE["/SetCurrent"])
        power = current * 230.0
        CHARGER_STATE["/Ac/Power"] = power
        CHARGER_STATE["/Ac/L1/Power"] = power
        CHARGER_STATE["/Current"] = current
        CHARGER_STATE["/ChargingTime"] =
            Int32(CHARGER_STATE["/ChargingTime"] + Int32(1))
        CHARGER_STATE["/Ac/Energy/Forward"] =
            Float64(CHARGER_STATE["/Ac/Energy/Forward"] + power / 3600000.0)
    else
        CHARGER_STATE["/Ac/Power"] = Float64(0.0)
        CHARGER_STATE["/Ac/L1/Power"] = Float64(0.0)
        CHARGER_STATE["/Current"] = Float64(0.0)
    end
end

# ── Main ──────────────────────────────────────────────────────────

function main()
    println("=== Venus OS EV Charger Demo ===")
    println("Connecting to session bus...")

    conn = DBusConnection(DBUS_BUS_SESSION)
    bus_name = "com.victronenergy.evcharger.julia_demo"
    ret = request_name(conn, bus_name)
    if ret != DBus.DBUS_REQUEST_NAME_REPLY_PRIMARY_OWNER
        error("Failed to acquire bus name '$bus_name' (ret=$ret)")
    end
    println("Registered as: $bus_name")
    println("Unique name:   $(unique_name(conn))")

    svc = DBusService(conn)
    register_charger_paths!(svc)

    # Simulate: set charger to "Connected + Charging"
    CHARGER_STATE["/Status"] = Int32(2)
    CHARGER_STATE["/StartStop"] = Int32(1)

    println("\nService running. Query with:")
    println("  busctl --user call $bus_name /Ac/Power com.victronenergy.BusItem GetValue")
    println("  busctl --user call $bus_name / com.victronenergy.BusItem GetItems")
    println("  busctl --user call $bus_name /SetCurrent com.victronenergy.BusItem SetValue v i 10")
    println("\nPress Ctrl+C to stop.\n")

    # Run service loop with periodic simulation updates
    while isopen(conn)
        if isready(svc.stop_channel)
            take!(svc.stop_channel)
            break
        end

        read_write_dispatch(conn; timeout_ms = 1000)

        # Drain messages
        while true
            msg_ptr = ccall(
                (:dbus_connection_pop_message, DBus.libdbus),
                Ptr{Cvoid},
                (Ptr{Cvoid},),
                conn.ptr,
            )
            msg_ptr == C_NULL && break
            msg = DBusMessage(msg_ptr; owns = true)
            DBus._handle_message(svc, msg)
        end

        # Simulate charging every loop iteration
        simulate_charging!()

        power = CHARGER_STATE["/Ac/Power"]
        energy = CHARGER_STATE["/Ac/Energy/Forward"]
        status = ["Disconnected", "Connected", "Charging", "Error"][CHARGER_STATE["/Status"] + 1]
        print("\r  Status: $status | Power: $(round(power; digits=0)) W | Energy: $(round(energy; digits=3)) kWh    ")
    end

    close(conn)
    println("\n=== Stopped ===")
end

main()
