# note: this is based heavily on `nixos/modules/services/misc/dictd.nix`
# from `nixpkgs`.
{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.services.dictd;

in {
  meta.maintainers = [ maintainers.mhueschen ];

  options.services.dictd = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = lib.mdDoc ''
        Whether to enable the DICT.org dictionary server.
      '';
    };

    package = mkOption {
      type = types.package;
      default = pkgs.dict;
      defaultText = literalExpression "pkgs.dict";
      description = "Which dict package to install.";
    };

    DBs = mkOption {
      type = types.listOf types.package;
      default = with pkgs.dictdDBs; [ wiktionary wordnet ];
      defaultText = literalExpression "with pkgs.dictdDBs; [ wiktionary wordnet ]";
      example = literalExpression "[ pkgs.dictdDBs.nld2eng ]";
      description = lib.mdDoc "List of databases to make available.";
    };
  };

  # TODO figure out how to adapt `dictDBCollector` to user-install location:
  # https://github.com/NixOS/nixpkgs/blob/8ff7b290e6dd47d7ed24c6d156ba60fc3c83f100/pkgs/servers/dict/dictd-db-collector.nix
  config = let dictdb = pkgs.dictDBCollector { dictlist = map (x: {
               name = x.name;
               filename = x; } ) cfg.DBs; };
  in mkIf cfg.enable {

    assertions = [
      (lib.hm.assertions.assertPlatform "services.dictd" pkgs
        lib.platforms.linux)
    ];

    home.packages = [ cfg.package ];

    # TODO change this config to live in user dir
    environment.etc."dict.conf".text = ''
      server localhost
    '';

    # TODO this config should not be a root-level systemd.
    # change it to be a `systemd.user.services` user-systemd thingy.
    # source:
    # https://github.com/NixOS/nixpkgs/blob/6b13dd0e9e7e0097bf796394386f0e88c33b172e/nixos/modules/services/misc/dictd.nix
    systemd.services.dictd = {
      description = "DICT.org Dictionary Server";
      wantedBy = [ "multi-user.target" ];
      environment = { LOCALE_ARCHIVE = "/run/current-system/sw/lib/locale/locale-archive"; };
      serviceConfig.Type = "forking";
      script = "${pkgs.dict}/sbin/dictd -s -c ${dictdb}/share/dictd/dictd.conf --locale en_US.UTF-8";
    };
  };
}
