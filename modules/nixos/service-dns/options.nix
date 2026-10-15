{
  lib,
  ...
}:
with lib;
{
  options.cfg.localdns = {
    enable = mkEnableOption "local DNS server (dnsmasq) with a split-horizon zone";

    domain = mkOption {
      type = types.str;
      default = "example.com";
      description = ''
        The real (publicly-owned) apex domain to host a split-horizon zone
        under. The internal zone served by dnsmasq is "<label>.<domain>" (see
        cfg.localdns.label). Use a domain you own so the internal zone is
        future-proof — a name like "<service>.<label>.<domain>" can be dual-homed
        (internal via dnsmasq, public via a tunnel) without renaming.

        The default "example.com" is the RFC 2606 documentation placeholder — set
        it to a domain you actually own. Do NOT use a made-up TLD (ICANN may
        delegate it later) or ".local" (reserved for mDNS — macOS and
        systemd-resolved route ".local" to mDNS first, making unicast subdomains
        flaky).
      '';
    };

    label = mkOption {
      type = types.str;
      default = "lan";
      description = ''
        Subdomain label prepended to cfg.localdns.domain to form the internal
        zone, e.g. "lan" + "example.com" → "lan.example.com". The label is just
        a namespacing choice under a domain you own, so it has no reservation
        risk; common picks are "lan", "int", "svc", "home".
      '';
    };

    # Computed (read-only) — the zone dnsmasq serves and that service vhosts
    # use as their server_name base (e.g. "hermes.${internalDomain}").
    internalDomain = mkOption {
      type = types.str;
      readOnly = true;
      description = "The internal zone = \"\${label}.\${domain}\". Read-only.";
    };

    address = mkOption {
      type = types.str;
      default = "127.0.0.1";
      example = "192.168.1.10";
      description = ''
        IPv4 address that "*.\${internalDomain}" and "\${internalDomain}" resolve
        to via a dnsmasq wildcard record. Typically the host's LAN IP (from
        cfg.networking.static.interfaces) so LAN clients reach this host's
        services by name. Defaults to loopback — set explicitly for a homelab.
      '';
    };

    extraRecords = mkOption {
      type = types.attrsOf types.str;
      default = { };
      example = literalExpression ''
        {
          "workstation.lan.example.com" = "192.168.0.170";
          "printer.lan.example.com" = "192.168.0.50";
        }
      '';
      description = ''
        Extra A records, mapping a fully-qualified name → IPv4. Use full names
        (including the internal zone) — they are emitted as dnsmasq
        `address=/name/ip` entries. Useful for naming other hosts on the LAN
        that don't run a DNS server themselves.
      '';
    };

    useAsHostResolver = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Repoint this host's own resolver to 127.0.0.1 (the local dnsmasq) so
        the host resolves its own internal zone (e.g. "hermes.lan.example.com"
        from the host itself). dnsmasq forwards non-local queries to
        cfg.networking.domain_name_servers, so upstream resolution is
        preserved. Uses mkForce to override service-networking's static
        `networking.nameservers` assignment.
      '';
    };

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Open the firewall for DNS (53 tcp+udp) so LAN clients can query this
        dnsmasq. Defaults to true — the module owns the DNS port.
      '';
    };
  };

}