{ ... }:
{
    # enable development documentation
    documentation.dev.enable = true;

    # enable kernel debugging disabled in security hardening profile
    boot.kernel.sysctl."kernel.ftrace_enabled" = true;

    # enable rabbitmq on localhost for various purposes
    services.rabbitmq.enable = true;

    # setcap wrappers and stuff
    programs = {
        adb.enable = true;
        wireshark.enable = true;
    };
}
