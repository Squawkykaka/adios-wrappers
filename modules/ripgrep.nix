{ types, promise, assertions, ... }:
{
  inputs = {
    mkWrapper.from = { parent }: parent.mkWrapper;
    nixpkgs.from = { parent }: parent.nixpkgs;
  };

  options = {
    flags = {
      type = types.listOf types.string;
      description = ''
        Flags to be automatically appended when running ripgrep.

        See the [documentation](https://manpages.ubuntu.com/manpages/jammy/man1/rg.1.html#:~:text=OPTIONS) of valid flags.

        Disjoint with the `configFile` option.
      '';
    };
    configFile = {
      type = types.pathLike;
      description = ''
        `ripgreprc` file, containing flags to be automatically appended when running ripgrep.

        See the [documentation](https://manpages.ubuntu.com/manpages/jammy/man1/rg.1.html#:~:text=OPTIONS) of valid flags.

        This file should have each flag on its own line. See the [documentation](https://github.com/BurntSushi/ripgrep/blob/master/GUIDE.md#configuration-file) of the file's format.

        Disjoint with the `configFile` option.
      '';
    };

    package = {
      type = types.derivation;
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.ripgrep;
      description = "The ripgrep package to be wrapped.";
    };
  };

  assertions = [
    (assertions.disjoint "flags" "configFile")
  ];

  result = promise (
    { options, inputs }:
    if options ? flags then
      inputs.mkWrapper {
        inherit (options) package flags;
      }
    else
      inputs.mkWrapper {
        environment = {
          RIPGREP_CONFIG_PATH = options.configFile or null;
        };
      }
  );

  meta = {
    maintainers = [ "llakala" ];
  };
}
