{ types, promise, ... }:
{
  inputs = {
    mkWrapper.from = { parent }: parent.mkWrapper;
    nixpkgs.from = { parent }: parent.nixpkgs;
  };

  options = {
    configContents = {
      type = types.string;
      description = ''
        Contents of the wrapped package's `nnn.rc`.

        See the [documentation](https://github.com/jarun/nnn/wiki/Usage#configuration) for syntax and valid options.

        Disjoint with the `configFile` option.
      '';
    };
    configFile = {
      type = types.pathLike;
      description = ''
        `nnn.rc` file to be injected into the wrapped package.

        See the [documentation](https://github.com/jarun/nnn/wiki/Usage#configuration) for syntax and valid options.

        Disjoint with the `configContents` option.
      '';
    };

    flags = {
      type = types.listOf types.string;
      description = ''
        Flags to be automatically appended when running nnn.
      '';
    };

    package = {
      type = types.derivation;
      default = promise ({ inputs }: inputs.nixpkgs.pkgs.nnn);
      description = "The nnn package to be wrapped.";
    };
  };

  result = promise (
    { options, inputs }:
    let
      inherit (inputs.nixpkgs.pkgs) writeText;
    in
    assert !(options ? configContents && options ? configFile);
    inputs.mkWrapper {
      inherit (options) package;
      flags = options.flags or [];
      symlinks = {
        "$out/nnn/nnn.rc" =
          if options ? configFile then
            options.configFile
          else if options ? configContents then
            writeText "nnn.rc" options.configContents
          else
            null;
      };
      environment = {
        XDG_CONFIG_HOME = "$out";
      };
    }
  );

  meta = {
    maintainers = [ "yarn" ];
  };
}
