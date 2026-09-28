{ types, promise, assertions, ... }:
{
  inputs = {
    mkWrapper.from = { parent }: parent.mkWrapper;
    nixpkgs.from = { parent }: parent.nixpkgs;
  };

  options = {
    settings = {
      type = types.attrs;
      description = ''
        Settings to be injected into the wrapped package's `wiremix.toml`.

        See the [documentation](https://github.com/tsowell/wiremix/blob/main/wiremix.toml) for syntax and valid options.

        Disjoint with the `configFile` option.
      '';
    };
    configFile = {
      type = types.pathLike;
      description = ''
        `wiremix.toml` file to be injected into the wrapped package.

        See the [documentation](https://github.com/tsowell/wiremix/blob/main/wiremix.toml) for syntax and valid options.

        Disjoint with the `settings` option.
      '';
    };

    package = {
      type = types.derivation;
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.wiremix;
      description = "The wiremix package to be wrapped.";
    };
  };

  assertions = [
    (assertions.disjoint "settings" "configFile")
  ];

  result = promise (
    { options, inputs }:
    let
      inherit (inputs.nixpkgs) pkgs;
      generator = pkgs.formats.toml {};
    in
    inputs.mkWrapper {
      inherit (options) package;
      symlinks = {
        "$out/wiremix/wiremix.toml" =
          if options ? configFile then
            options.configFile
          else if options ? settings then
            generator.generate "wiremix.toml" options.settings
          else
            null;
      };
      environment = {
        XDG_CONFIG_HOME = "$out";
      };
    }
  );

  meta = {
    maintainers = [];
  };
}
