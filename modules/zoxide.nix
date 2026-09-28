{ types, promise, ... }:
{
  inputs = {
    mkWrapper.from = { parent }: parent.mkWrapper;
    nixpkgs.from = { parent }: parent.nixpkgs;
  };

  options = {
    flags = {
      type = types.listOf types.string;
      description = ''
        Flags to be automatically appended when creating the zoxide shell integration.

        See the [documentation](https://github.com/ajeetdsouza/zoxide#flags) of valid flags.
      '';
      default = [];
    };

    excludedDirs = {
      type = types.string;
      description = ''
        Directory globs that won't be added to the database when navigating with zoxide.
      '';
    };

    package = {
      type = types.derivation;
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.zoxide;
      description = "The zoxide package to be wrapped.";
    };
  };

  mutations = {
    "/fish".interactiveShellInit =
      { options, inputs }:
      let
        inherit (inputs.nixpkgs.lib) getExe;
        inherit (builtins) concatStringsSep;
        finalWrapper = options {};
      in
      # fish
      ''
        ${getExe finalWrapper} init fish ${concatStringsSep " " options.flags} | source
      '';
  };

  result = promise (
    { options, inputs }:
    inputs.mkWrapper {
      inherit (options) package;
      environment = {
        _ZO_EXCLUDE_DIRS = options.excludedDirs or null;
      };
    }
  );

  meta = {
    maintainers = [ "llakala" ];
  };
}
