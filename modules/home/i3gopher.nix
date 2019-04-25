{ config, pkgs, lib, ... }: with lib; let
  cfg = config.xsession.windowManager.i3.i3gopher;
in {
  options.xsession.windowManager.i3.i3gopher = {
    enable = mkEnableOption "i3 focus history";
    exec = mkOption {
      description = "command to execute on any window event";
      type = types.nullOr types.str;
      example = "killall -USR1 i3status";
      default = null;
    };
  };

  config.systemd.user.services = mkIf cfg.enable {
    i3gopher = {
      Unit = {
        Description = "i3 focus history";
        After = ["graphical-session-i3.target"];
        PartOf = ["graphical-session.target"];
      };
      Service = {
        Type = "exec";
        Restart = "on-failure";
        # TODO: systemd/shell string escapes
        ${if cfg.exec != null then "Environment" else null} = ["I3GOPHER_EXEC=\"${cfg.exec}\""];
        ExecStart = if cfg.exec != null
          then "${pkgs.arc.i3gopher.exec} -exec \${I3GOPHER_EXEC}"
          else pkgs.arc.i3gopher.exec;
      };
      Install.WantedBy = ["graphical-session-i3.target"];
    };
  };
}