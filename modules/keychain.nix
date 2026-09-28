{ types, promise, ... }:
let
  inherit (builtins) concatStringsSep;
  command =
    opts:
    "${opts.package}/bin/keychain --eval --absolute --dir $XDG_RUNTIME_DIR/keychain ${
      concatStringsSep " " (opts.flags ++ opts.keys)
    }";
in {
  inputs = {
    mkWrapper.from = { parent }: parent.mkWrapper;
    nixpkgs.from = { parent }: parent.nixpkgs;
  };

  options = {
    flags = {
      type = types.listOf types.string;
      default = [];
      description = ''
        Flags to be injected into the wrapped package.

        See keychain's [readme](https://github.com/danielrobbins/keychain#2-embedded-documentation) on GitHub for valid options.
      '';
    };

    keys = {
      # Intentionally not listOf<pathLike>, since we don't want keys to be copied to the store
      type = types.listOf types.string;
      default = [];
      description = "Paths to keys to be added to the wrapped package.";
      example = [ "~/.ssh/id_ed25519" ];
    };

    package = {
      type = types.derivation;
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.keychain;
      description = "The keychain package to wrap.";
    };
  };

  mutations = {
    "/fish".interactiveShellInit = promise ({ options }: "eval (${command options})");
    "/zsh".zshrc = promise ({ options }: ''eval "$(${command options})"'');
    # Adapted from hm
    # https://github.com/nix-community/home-manager/blob/aa308770461dcf22c333a5e8a31c8bddbde5bee9/modules/programs/keychain.nix#L115
    "/nushell".shellInit = promise (
      { options }: ''
        let keychain_shell_command = (SHELL=bash ${command options}| parse -r '(\w+)="?(.*?)"?; export \1' | transpose -ird)
        if not ($keychain_shell_command|is-empty) {
          $keychain_shell_command | load-env
        }
      ''
    );
  };

  meta = {
    maintainers = [ "itsyunaya" ];
  };
}
