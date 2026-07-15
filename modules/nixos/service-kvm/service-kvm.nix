{
  config,
  lib,
  pkgs,
  options,
  ...
}:
with lib;
let
  cfg = config.cfg.kvm;

  # ───────── CPU vendor detection ─────────
  # Derives from boot.kernelModules (declared in hardware-configuration.nix)
  # with /proc/cpuinfo probing as a last-resort fallback.
  cpuVendor =
    let
      v = cfg.host.cpuVendor;
    in
    if v != "auto" then
      v
    else if builtins.elem "kvm-intel" config.boot.kernelModules then
      "intel"
    else if builtins.elem "kvm-amd" config.boot.kernelModules then
      "amd"
    else
      builtins.readFile (
        pkgs.runCommand "cpu-vendor.txt" { } ''
          ((cat /proc/cpuinfo | grep vendor | head -n 1 | grep -i intel > /dev/null 2>&1) \
            && echo -n 'intel' || echo -n 'amd') > $out
        ''
      );

  # ───────── IOMMU auto-detection ─────────
  # Active when the user forces it OR any guest requests PCI passthrough.
  anyGuestPciPassthrough = lib.any (g: (g.passthrough.pci or [ ]) != [ ]) (
    builtins.attrValues cfg.guests
  );

  iommuActive = cfg.host.kernel.iommu.enable || anyGuestPciPassthrough;

  # ───────── Bundled hook scripts ─────────
  gpuPassthroughHook = pkgs.writeShellScript "gpu-passthrough" (
    builtins.readFile ./libvirt_hooks/gpu-passthrough.sh
  );

  libvirtNosleepHook = pkgs.writeShellScript "libvirt-nosleep" (
    builtins.readFile ./libvirt_hooks/libvirt-nosleep.sh
  );

  bundledHookMap = {
    "gpu-passthrough" = gpuPassthroughHook;
    "libvirt-nosleep" = libvirtNosleepHook;
  };

  # Generate the bundled hooks attrset from the user's selection.
  bundledHooks = lib.genAttrs cfg.host.libvirtd.hooks.bundled (name: bundledHookMap.${name});

  # ───────── Storage pool XML ─────────
  persistentPoolXML = pkgs.writeText "kvm-persistent-pool.xml" ''
    <pool type='dir'>
      <name>kvm-persistent</name>
      <target>
        <path>${cfg.host.storage.persistentPath}</path>
      </target>
    </pool>
  '';
in
{
  imports = [
    ../service-networking/service-networking.nix
    ./options.nix
    ./guests.nix
  ];

  config = mkMerge [
    {
      # ───────── Kernel / KVM modules ─────────
      boot.kernelModules = cfg.host.kernel.extraModules ++ optional iommuActive "vfio-pci";
      boot.kernelParams =
        cfg.host.kernel.extraParams
        ++ optionals iommuActive [
          "iommu=${cfg.host.kernel.iommu.mode}"
          "${cpuVendor}_iommu=on"
        ];
      boot.extraModprobeConfig = ''
        options kvm_${cpuVendor} nested=${if cfg.host.kernel.nested then "1" else "0"}
        options kvm ignore_msrs=${if cfg.host.kernel.ignoreMsrs then "1" else "0"}
      '';

      # ───────── libvirtd daemon ─────────
      virtualisation.libvirtd = {
        enable = true;
        onBoot = cfg.host.libvirtd.onBoot;
        onShutdown = cfg.host.libvirtd.onShutdown;
        parallelShutdown = cfg.host.libvirtd.parallelShutdown;
        shutdownTimeout = cfg.host.libvirtd.shutdownTimeout;
        startDelay = cfg.host.libvirtd.startDelay;
        allowedBridges = cfg.host.libvirtd.allowedBridges;
        extraConfig = cfg.host.libvirtd.extraConfig;
        extraOptions = cfg.host.libvirtd.extraOptions;
        firewallBackend = cfg.host.libvirtd.firewallBackend;
        qemu = {
          runAsRoot = cfg.host.libvirtd.runAsRoot;
          swtpm.enable = cfg.host.libvirtd.swtpm;
        };
        hooks.qemu = bundledHooks // cfg.host.libvirtd.hooks.qemu;
      };

      # ───────── Packages / tools ─────────
      environment.systemPackages =
        optionals cfg.host.tools.enable (
          with pkgs;
          [
            qemu
            virt-manager
            dconf
            libguestfs
            pciutils
            python3
            iproute2
          ]
        )
        ++ cfg.host.tools.extraPackages;

      # ───────── User / permissions ─────────
      users.users."${cfg.host.user}".extraGroups = [ "libvirtd" ];

      security.pam.loginLimits = [
        {
          domain = "libvirtd";
          type = "soft";
          item = "memlock";
          value = "unlimited";
        }
        {
          domain = "libvirtd";
          type = "hard";
          item = "memlock";
          value = "unlimited";
        }
      ];

      # ───────── XRDP for remote VM control ─────────
      services.xrdp.enable = cfg.host.xrdp.enable;
      systemd.services.pcscd.enable = mkIf cfg.host.xrdp.enable false;
      systemd.sockets.pcscd.enable = mkIf cfg.host.xrdp.enable false;

      # ───────── libvirtd service path (for hooks) ─────────
      systemd.services.libvirtd.path =
        let
          env = pkgs.buildEnv {
            name = "qemu-hook-env";
            paths = with pkgs; [
              bash
              libvirt
              kmod
              systemd
              ripgrep
              sd
            ];
          };
        in
        [ env ];

      # ───────── Host networking (bridges) ─────────
      networking.bridges = listToAttrs (
        map (
          b:
          nameValuePair b.name {
            interfaces = optional (b.interface != null) b.interface;
          }
        ) cfg.host.networking.bridges
      );

      networking.interfaces = listToAttrs (
        flatten (
          map (
            b:
            optional (b.address != null) (
              nameValuePair b.name {
                ipv4.addresses = [
                  {
                    address = b.address;
                    prefixLength = b.prefixLength;
                  }
                ];
              }
            )
          ) cfg.host.networking.bridges
        )
      );
    }

    # ───────── Persistent storage pool ─────────
    (mkIf (cfg.host.storage.persistentPath != null) {
      systemd.services.kvm-host-setup = {
        description = "KVM host storage pool setup";
        after = [ "libvirtd.service" ];
        requires = [ "libvirtd.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        path = [ config.virtualisation.libvirtd.package ];
        script = ''
          mkdir -p "${cfg.host.storage.persistentPath}"
          virsh pool-define "${persistentPoolXML}" 2>/dev/null || true
          virsh pool-start kvm-persistent 2>/dev/null || true
          virsh pool-autostart kvm-persistent 2>/dev/null || true
        '';
      };
    })

    # ───────── libvirt-nosleep template service ─────────
    (mkIf (elem "libvirt-nosleep" cfg.host.libvirtd.hooks.bundled) {
      systemd.services."libvirt-nosleep@" = {
        unitConfig.Description = ''Preventing sleep while libvirt domain "%i" is running'';
        serviceConfig = {
          Type = "simple";
          ExecStart = ''/run/current-system/sw/bin/systemd-inhibit --what=sleep --why="Libvirt domain \"%i\" is running" --who=%U --mode=block sleep infinity'';
        };
      };
    })

    # ───────── VFIO PCI device binding ─────────
    # When any guest requests PCI passthrough, bind the devices to vfio-pci at boot.
    (mkIf iommuActive {
      boot.extraModprobeConfig = mkAfter ''
        ${optionalString anyGuestPciPassthrough ''
          options vfio-pci ids=${
            concatStringsSep "," (
              unique (concatLists (mapAttrsToList (_: g: map (d: d.id) g.passthrough.pci) cfg.guests))
            )
          }
        ''}
      '';
    })
  ];
}
