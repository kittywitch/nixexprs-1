{ pkgs, lib, config, ... }: let
  cfg = config.services.konawall;
  arc = import ../../canon.nix { inherit pkgs; };
  service = config.systemd.user.services.konawall;
in with lib; {
  options.services.konawall = {
    enable = mkEnableOption "enable konawall";
    mode = mkOption {
      type = types.str;
      default = "random";
    };
    commonTags = mkOption {
      type = types.listOf types.str;
      default = ["score:>=200" "width:>=1600"];
    };
    tags = mkOption {
      type = types.listOf types.str;
      default = ["nobody"];
    };
    tagList = mkOption {
      type = with types; listOf (listOf str);
      default = singleton cfg.tags;
    };
    package = mkOption {
      type = types.package;
      default = pkgs.konawall or arc.packages.konawall;
    };
    interval = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "20m";
      description = "How often to rotate backgrounds (specify as a systemd interval)";
    };
  };

  config.systemd.user = mkIf cfg.enable {
    services = {
      konawall = {
        Unit = rec {
          Description = "Random wallpapers";
          After = mkMerge [
            [ "graphical-session-pre.target" ]
            (mkIf config.wayland.windowManager.sway.enable [ "sway-session.target" ])
          ];
          PartOf = mkMerge [
            [ "graphical-session.target" ]
            (mkIf config.wayland.windowManager.sway.enable [ "sway-session.target" ])
          ];
          Requisite = PartOf;
        };
        Service = {
          Type = "oneshot";
          Environment = mkIf (config.xsession.enable) [
            "PATH=${makeBinPath (with pkgs; [ feh pkgs.xorg.xsetroot ])}"
          ];
          ExecStart = let
            tags = map (n: concatStringsSep "," n) cfg.tagList;
            tags-escaped = escapeShellArgs tags;
            common = concatStringsSep "," cfg.commonTags;
            common-escaped = escapeShellArg common;
          in "${cfg.package}/bin/konawall --mode ${cfg.mode} ${optionalString (cfg.commonTags != [ ]) "--common ${common-escaped}"} ${tags-escaped}";
          RemainAfterExit = true;
          IOSchedulingClass = "idle";
          TimeoutStartSec = "5m";
        };
        Install.WantedBy = mkMerge [
          (mkDefault [ "graphical-session.target" ])
          (mkIf config.wayland.windowManager.sway.enable [ "sway-session.target" ])
        ];
      };
      konawall-rotation = mkIf (cfg.interval != null) {
        Unit = {
          Description = "Random wallpaper rotation";
          inherit (service.Unit) Requisite;
        };
        Service = {
          Type = "oneshot";
          ExecStart = "${config.systemd.package or pkgs.systemd}/bin/systemctl --user restart konawall";
        };
      };
    };
    timers.konawall-rotation = mkIf (cfg.interval != null) {
      Unit = {
        inherit (service.Unit) After PartOf;
      };
      Timer = {
        OnUnitInactiveSec = cfg.interval;
        OnStartupSec = cfg.interval;
      };
      Install = {
        inherit (service.Install) WantedBy;
      };
    };
  };
}
