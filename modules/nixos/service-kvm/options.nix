{
  config,
  lib,
  pkgs,
  options,
  ...
}:
with lib;
let
  # Per-guest option submodule.
  # Follows the oci-containers pattern: { name, ... } where `name` is the attrset key.
  guestOptions =
    { name, ... }:
    {
      options = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Whether to enable this guest.";
        };

        # ───── Compute ─────
        memory = mkOption {
          type = types.ints.positive;
          default = 2048;
          description = "Memory allocation in MiB.";
        };
        vcpus = mkOption {
          type = types.ints.positive;
          default = 2;
          description = "Number of virtual CPUs.";
        };
        machineType = mkOption {
          type = types.str;
          default = "q35";
          description = "QEMU machine type (e.g. q35, pc-i440fx).";
        };
        architecture = mkOption {
          type = types.str;
          default = "x86_64";
          description = "Guest CPU architecture.";
        };
        cpuMode = mkOption {
          type = types.enum [
            "host-passthrough"
            "host-model"
            "custom"
          ];
          default = "host-passthrough";
          description = "CPU model exposed to the guest.";
        };

        # ───── Storage ─────
        storagePath = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = ''
            Relative path under the host's persistentPath for this guest's storage.
            When null, falls back to statePath/qemu/<name>.
          '';
        };
        disks = mkOption {
          type = types.listOf (
            types.submodule {
              options = {
                path = mkOption {
                  type = types.str;
                  description = ''
                    Disk path — relative name (no slashes, no extension) or absolute path.
                    Relative paths are joined with the guest's storage directory and
                    suffixed with the format extension (e.g. "disk0" → "disk0.qcow2").
                    Absolute paths are used as-is.
                  '';
                  example = "disk0";
                };
                format = mkOption {
                  type = types.enum [
                    "qcow2"
                    "raw"
                  ];
                  default = "qcow2";
                  description = "Disk image format.";
                };
                bus = mkOption {
                  type = types.enum [
                    "virtio"
                    "sata"
                    "ide"
                    "scsi"
                  ];
                  default = "virtio";
                  description = "Disk bus type.";
                };
                size = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = ''
                    Disk size (e.g. "50G"). Used when the disk image doesn't exist
                    yet — existing disks are never recreated. Required when creating
                    an empty disk; optional when downloading via sourceUrl (used to
                    resize the downloaded image).
                  '';
                  example = "50G";
                };
                sourceUrl = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = ''
                    URL to download a pre-built disk image from (e.g. a cloud image).
                    When set, the disk is downloaded instead of created empty.
                    Only used when the disk doesn't already exist. The downloaded
                    image is optionally resized to `size` if both are set.
                  '';
                  example = "https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img";
                };
                readOnly = mkOption {
                  type = types.bool;
                  default = false;
                  description = "Mount the disk read-only.";
                };
              };
            }
          );
          default = [ ];
          description = "Disk images for this guest.";
        };

        # ───── Boot / firmware ─────
        firmware = mkOption {
          type = types.enum [
            "bios"
            "uefi"
          ];
          default = "uefi";
          description = "Firmware type.";
        };
        secureBoot = mkOption {
          type = types.bool;
          default = false;
          description = "Enable UEFI Secure Boot (requires firmware = \"uefi\" and tpm.enable).";
        };
        bootDevice = mkOption {
          type = types.enum [
            "hd"
            "cdrom"
            "network"
            "fd"
          ];
          default = "hd";
          description = "Primary boot device.";
        };
        installISO = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = ''
            Local ISO image to attach as a CD-ROM device (for OS installation).
            Mutually exclusive with installISOUrl.
          '';
        };
        installISOUrl = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = ''
            URL to download an ISO image and attach it as a CD-ROM device
            (for OS installation). The ISO is downloaded to the guest's
            storage directory on first boot if it doesn't already exist.
            Mutually exclusive with installISO.
          '';
          example = "https://releases.ubuntu.com/24.04/ubuntu-24.04.2-desktop-amd64.iso";
        };

        # ───── Cloud-init ─────
        cloudInit = mkOption {
          type = types.submodule {
            options = {
              enable = mkOption {
                type = types.bool;
                default = false;
                description = ''
                  Generate a cloud-init seed ISO and attach it as a CD-ROM.
                  The guest's cloud image will read this on first boot to
                  configure the user, SSH keys, hostname, and packages
                  automatically — no manual installer interaction needed.
                '';
              };
              hostname = mkOption {
                type = types.str;
                default = name;
                description = "Hostname for the guest (set via cloud-init).";
              };
              user = mkOption {
                type = types.str;
                default = "user";
                description = "Primary user to create via cloud-init.";
              };
              passwordAgePath = mkOption {
                type = types.nullOr types.path;
                default = null;
                description = ''
                  Path to an age-encrypted file containing the user's password.
                  When set, the password is decrypted via agenix at runtime and
                  injected into the cloud-init user-data. Requires the agenix
                  NixOS module to be imported on the host.
                '';
              };
              sshAuthorizedKeys = mkOption {
                type = types.listOf types.str;
                default = [ ];
                description = "SSH public keys to authorize for the primary user.";
                example = [ "ssh-ed25519 AAAA..." ];
              };
              packages = mkOption {
                type = types.listOf types.str;
                default = [ ];
                description = "Packages to install via cloud-init on first boot.";
              };
              runcmd = mkOption {
                type = types.listOf types.str;
                default = [ ];
                description = "Commands to run on first boot.";
              };
              extraConfig = mkOption {
                type = types.lines;
                default = "";
                description = ''
                  Extra cloud-config YAML appended to the user-data.
                  Use for advanced cloud-init configuration not covered by
                  the other options.
                '';
              };
            };
          };
          default = { };
          description = "Cloud-init configuration for automated guest setup.";
        };

        # ───── TPM ─────
        tpm = mkOption {
          type = types.submodule {
            options = {
              enable = mkOption {
                type = types.bool;
                default = false;
                description = "Enable emulated TPM via swtpm.";
              };
              version = mkOption {
                type = types.enum [
                  "1.2"
                  "2.0"
                ];
                default = "2.0";
                description = "TPM specification version.";
              };
              model = mkOption {
                type = types.enum [
                  "tpm-crb"
                  "tpm-tis"
                ];
                default = "tpm-crb";
                description = "TPM device model.";
              };
            };
          };
          default = { };
          description = "TPM configuration.";
        };

        # ───── Networking ─────
        networks = mkOption {
          type = types.listOf (
            types.submodule {
              options = {
                type = mkOption {
                  type = types.enum [
                    "bridge"
                    "network"
                    "direct"
                    "user"
                  ];
                  default = "network";
                  description = ''
                    Interface type: bridge (host bridge), network (libvirt network),
                    direct (macvtap to physical NIC), or user (QEMU SLIRP NAT).
                  '';
                };
                source = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = ''
                    Source name — bridge name (for bridge), network name (for network),
                    or physical interface (for direct). Ignored for user type.
                  '';
                };
                model = mkOption {
                  type = types.enum [
                    "virtio"
                    "e1000"
                    "rtl8139"
                    "vmxnet3"
                  ];
                  default = "virtio";
                  description = "NIC model.";
                };
                mac = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "MAC address. Auto-generated if null.";
                };
              };
            }
          );
          default = [ ];
          description = "Network interfaces for this guest.";
        };

        # ───── Passthrough ─────
        passthrough = mkOption {
          type = types.submodule {
            options = {
              pci = mkOption {
                type = types.listOf (
                  types.submodule {
                    options = {
                      id = mkOption {
                        type = types.str;
                        description = ''
                          PCI device address in Proxmox/Linux BDF format
                          (e.g. "0000:01:00.0"). Run `lspci -nn` to find it.
                        '';
                        example = "0000:01:00.0";
                      };
                      pcie = mkOption {
                        type = types.bool;
                        default = false;
                        description = "Use PCIe bus (vs conventional PCI).";
                      };
                      romBar = mkOption {
                        type = types.bool;
                        default = true;
                        description = "Expose the device's option ROM to the guest.";
                      };
                      xVga = mkOption {
                        type = types.bool;
                        default = false;
                        description = "Mark as primary VGA device for the guest.";
                      };
                    };
                  }
                );
                default = [ ];
                description = "PCI devices to pass through to this guest.";
              };
              usb = mkOption {
                type = types.listOf (
                  types.submodule {
                    options = {
                      vendor = mkOption {
                        type = types.str;
                        description = "USB vendor ID (hex, e.g. \"0bda\").";
                        example = "0bda";
                      };
                      product = mkOption {
                        type = types.str;
                        description = "USB product ID (hex, e.g. \"5411\").";
                        example = "5411";
                      };
                    };
                  }
                );
                default = [ ];
                description = "USB devices to pass through to this guest.";
              };
            };
          };
          default = { };
          description = "Host device passthrough configuration.";
        };

        # ───── Graphics / input / video ─────
        graphics = mkOption {
          type = types.submodule {
            options = {
              type = mkOption {
                type = types.enum [
                  "spice"
                  "vnc"
                  "none"
                ];
                default = "spice";
                description = "Graphics protocol.";
              };
              listen = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = ''
                  Address to listen on. Null means local-only (127.0.0.1).
                  Use "0.0.0.0" for remote access.
                '';
              };
              port = mkOption {
                type = types.nullOr types.int;
                default = null;
                description = "Fixed port number. Auto-allocated when null.";
              };
              passwordAgePath = mkOption {
                type = types.nullOr types.path;
                default = null;
                description = ''
                  Path to an age-encrypted file containing the graphics password.
                  When set, the password is decrypted via agenix and applied to
                  the SPICE/VNC server after VM start. When null, no password is set.
                '';
              };
            };
          };
          default = { };
          description = "Graphics configuration.";
        };
        input = mkOption {
          type = types.submodule {
            options = {
              tablet = mkOption {
                type = types.bool;
                default = true;
                description = "USB tablet input device (pointer alignment for SPICE/VNC).";
              };
              keyboard = mkOption {
                type = types.bool;
                default = true;
                description = "Keyboard input device.";
              };
              mouse = mkOption {
                type = types.bool;
                default = true;
                description = "Mouse input device.";
              };
            };
          };
          default = { };
          description = "Input device configuration.";
        };
        video = mkOption {
          type = types.submodule {
            options = {
              model = mkOption {
                type = types.enum [
                  "qxl"
                  "virtio"
                  "vga"
                  "cirrus"
                  "none"
                ];
                default = "qxl";
                description = "Video card model.";
              };
              heads = mkOption {
                type = types.ints.positive;
                default = 1;
                description = "Number of display heads.";
              };
            };
          };
          default = { };
          description = "Video configuration.";
        };

        # ───── Lifecycle ─────
        autoStart = mkOption {
          type = types.bool;
          default = true;
          description = "Automatically start this guest on boot.";
        };
        dependsOn = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = ''
            Other guest names this one depends on. Sets systemd After/Requires
            ordering — does not wait for guest services to be healthy.
          '';
          example = [ "router-vm" ];
        };

        # ───── Escape hatch ─────
        extraXML = mkOption {
          type = types.nullOr types.lines;
          default = null;
          description = ''
            Raw libvirt domain XML to merge into the generated definition.
            Inserted before the closing </domain> tag.
          '';
        };
        extraQemuArgs = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Extra QEMU command-line arguments (via <qemu:commandline>).";
        };
      };
    };
in
{
  imports = [ ../service-networking/options.nix ];

  options.cfg.kvm.host = {
    cpuVendor = mkOption {
      type = types.enum [
        "intel"
        "amd"
        "auto"
      ];
      default = "auto";
      description = ''
        CPU vendor for KVM module selection and IOMMU parameter generation.
        "auto" derives from boot.kernelModules (kvm-intel → intel, kvm-amd → amd),
        falling back to /proc/cpuinfo probing if neither is found.
      '';
    };

    kernel = mkOption {
      type = types.submodule {
        options = {
          extraModules = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "Additional kernel modules to load.";
          };
          extraParams = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "Additional kernel parameters.";
          };
          nested = mkOption {
            type = types.bool;
            default = true;
            description = "Enable nested virtualization (KVM inside KVM).";
          };
          ignoreMsrs = mkOption {
            type = types.bool;
            default = true;
            description = "Have KVM ignore MSR accesses it doesn't recognize.";
          };
          iommu = mkOption {
            type = types.submodule {
              options = {
                enable = mkOption {
                  type = types.bool;
                  default = false;
                  description = ''
                    Force-enable IOMMU even when no guest declares PCI passthrough.
                    IOMMU is automatically enabled when any guest uses passthrough.pci;
                    this option lets you prepare the host before any such guest is defined.
                  '';
                };
                mode = mkOption {
                  type = types.enum [
                    "pt"
                    "off"
                  ];
                  default = "pt";
                  description = "IOMMU mode: pt (passthrough) or off.";
                };
              };
            };
            default = { };
            description = "IOMMU configuration.";
          };
        };
      };
      default = { };
      description = "Kernel and KVM module configuration.";
    };

    libvirtd = mkOption {
      type = types.submodule {
        options = {
          onBoot = mkOption {
            type = types.enum [
              "start"
              "ignore"
            ];
            default = "ignore";
            description = "Action on formerly running guests when the host boots.";
          };
          onShutdown = mkOption {
            type = types.enum [
              "shutdown"
              "suspend"
            ];
            default = "shutdown";
            description = "Method used to halt guests on host shutdown.";
          };
          parallelShutdown = mkOption {
            type = types.ints.unsigned;
            default = 0;
            description = "Number of guests shutdown concurrently (0 = sequential).";
          };
          shutdownTimeout = mkOption {
            type = types.ints.unsigned;
            default = 300;
            description = "Seconds to wait for guests to shut down.";
          };
          startDelay = mkOption {
            type = types.ints.unsigned;
            default = 0;
            description = "Seconds to wait between each guest start (0 = parallel).";
          };
          runAsRoot = mkOption {
            type = types.bool;
            default = true;
            description = "Run QEMU as root (vs qemu-libvirtd user).";
          };
          swtpm = mkOption {
            type = types.bool;
            default = true;
            description = "Enable swtpm for emulated TPM devices.";
          };
          allowedBridges = mkOption {
            type = types.listOf types.str;
            default = [ "virbr0" ];
            description = "Bridges allowed for qemu:///session.";
          };
          firewallBackend = mkOption {
            type = types.enum [
              "iptables"
              "nftables"
            ];
            default = "iptables";
            description = "Firewall backend for libvirt network rules.";
          };
          extraConfig = mkOption {
            type = types.lines;
            default = "";
            description = "Extra contents appended to libvirtd.conf.";
          };
          extraOptions = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "Extra command-line arguments passed to libvirtd.";
          };
          hooks = mkOption {
            type = types.submodule {
              options = {
                bundled = mkOption {
                  type = types.listOf (
                    types.enum [
                      "gpu-passthrough"
                      "libvirt-nosleep"
                    ]
                  );
                  default = [ ];
                  description = ''
                    Bundled hook scripts to install under libvirt's hooks directory.

                    - "gpu-passthrough": unbinds PCI hostdevs from the host driver
                      before VM start and rebinds them after VM stop.
                    - "libvirt-nosleep": inhibits host sleep while any VM is running.
                  '';
                };
                qemu = mkOption {
                  type = types.attrsOf types.path;
                  default = { };
                  description = ''
                    Custom QEMU hook scripts (passed through to
                    virtualisation.libvirtd.hooks.qemu). Keys are script names.
                  '';
                };
              };
            };
            default = { };
            description = "Libvirt hook configuration.";
          };
        };
      };
      default = { };
      description = "libvirtd daemon configuration.";
    };

    storage = mkOption {
      type = types.submodule {
        options = {
          statePath = mkOption {
            type = types.path;
            default = "/var/lib/libvirt";
            description = ''
              Libvirt state directory. Contains daemon config, runtime state,
              and the default storage location for guests without a storagePath.
              This is on the root filesystem and may not survive reimaging.
            '';
          };
          persistentPath = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = ''
              Base directory for persistent guest storage (e.g. on a ZFS dataset
              or separate disk). When set, guests with a storagePath store their
              disks here. Also registered as a libvirt storage pool for
              visibility in virt-manager. When null, guests fall back to statePath.
            '';
          };
        };
      };
      default = { };
      description = "Storage paths.";
    };

    networking = mkOption {
      type = types.submodule {
        options = {
          bridges = mkOption {
            type = types.listOf (
              types.submodule {
                options = {
                  name = mkOption {
                    type = types.str;
                    description = "Bridge interface name (e.g. \"br0\").";
                  };
                  interface = mkOption {
                    type = types.nullOr types.str;
                    default = null;
                    description = "Physical NIC to enslave to this bridge.";
                  };
                  address = mkOption {
                    type = types.nullOr types.str;
                    default = null;
                    description = "IPv4 address for this bridge.";
                  };
                  prefixLength = mkOption {
                    type = types.ints.unsigned;
                    default = 24;
                    description = "Subnet prefix length.";
                  };
                };
              }
            );
            default = [ ];
            description = ''
              Host bridges to create. Guests can attach to these via
              networks[].type = "bridge". The default libvirt NAT bridge (virbr0)
              is always available.
            '';
          };
        };
      };
      default = { };
      description = "Host networking.";
    };

    user = mkOption {
      type = types.str;
      default = config.cfg.user.name;
      defaultText = literalExpression "config.cfg.user.name";
      description = "User to add to the libvirtd group.";
    };

    tools = mkOption {
      type = types.submodule {
        options = {
          enable = mkOption {
            type = types.bool;
            default = true;
            description = "Install KVM/QEMU management tools.";
          };
          extraPackages = mkOption {
            type = types.listOf types.package;
            default = [ ];
            description = "Additional packages to install.";
          };
        };
      };
      default = { };
      description = "Management tooling.";
    };

    xrdp = mkOption {
      type = types.submodule {
        options = {
          enable = mkOption {
            type = types.bool;
            default = true;
            description = ''
              Enable xrdp for remote control of VMs via RDP.
              Useful for remote_logout and remote_unlock.
            '';
          };
        };
      };
      default = { };
      description = "XRDP remote desktop configuration.";
    };
  };

  options.cfg.kvm.guests = mkOption {
    type = types.attrsOf (types.submodule guestOptions);
    default = { };
    description = "Declarative QEMU/KVM guests registered with libvirt.";
  };
}
