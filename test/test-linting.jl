
@testitem "Aqua" tags = [:linting] begin
    using Aqua: Aqua
    using DBus

    Aqua.test_all(DBus)
end

@testitem "JET" tags = [:linting] begin
    if v"1.12" <= VERSION < v"1.13"
        using JET: JET
        using DBus

        JET.test_package(DBus; target_modules = (DBus,))
    end
end
