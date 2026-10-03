{ types, promise, assertions, ... }:
{
  inputs = {
    mkWrapper.from = { parent }: parent.mkWrapper;
    nixpkgs.from = { parent }: parent.nixpkgs;
  };

  options = {
    configContents = {
      type = types.string;
      description = ''
        Settings to be injected into the wrapped package's `config` file.

        See the [documentation](https://man.archlinux.org/man/swayidle.1) for valid options.

        Disjoint with the `configFile` option.
      '';
    };
    configFile = {
      type = types.pathLike;
      description = ''
        `config` file to be injected into the wrapped package.

        See the [documentation](https://man.archlinux.org/man/swayidle.1) for valid options.

        Disjoint with the `configContents` option.
      '';
    };

    seatName = {
      type = types.string;
      description = "The seat name to be injected into the wrapped package's flags.";
    };

    package = {
      type = types.derivation;
      default = promise ({ inputs }: inputs.nixpkgs.pkgs.swayidle);
      description = "The swayidle package to be wrapped.";
    };
  };

  assertions = [
    (assertions.disjoint "configContents" "configFile")
  ];

  result = promise (
    { options, inputs }:
    let
      inherit (inputs.nixpkgs.pkgs) writeText;
      configFlag =
        if options ? configContents || options ? configFile then
          [
            "-C"
            "$out/config"
          ]
        else
          [];
      styleFlag =
        if options ? seat then
          [
            "-S"
            options.seat
          ]
        else
          [];
    in
    inputs.mkWrapper {
      inherit (options) package;
      symlinks = {
        "$out/config" =
          if options ? configContents then
            writeText "config" options.configContents
          else if options ? configFile then
            options.configFile
          else
            null;
      };
      flags = configFlag ++ styleFlag;
    }
  );

  meta = {
    maintainers = [];
  };
}
