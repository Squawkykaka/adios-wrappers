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
        Settings to be injected into the wrapped package's `config.toml`.

        See the tealdeer [documentation](https://tealdeer-rs.github.io/tealdeer/config.html).

        Disjoint with the `configFile` option.
      '';
    };
    configFile = {
      type = types.pathLike;
      description = ''
        `config.toml` file to be injected into the wrapped package.

        See the tealdeer [documentation](https://tealdeer-rs.github.io/tealdeer/config.html).

        Disjoint with the `settings` option.
      '';
    };

    package = {
      type = types.derivation;
      default = promise ({ inputs }: inputs.nixpkgs.pkgs.tealdeer);
      description = "The tealdeer package to be wrapped.";
    };
  };

  assertions = [
    (assertions.disjoint "settings" "configFile")
  ];

  result = promise (
    { options, inputs }:
    let
      inherit (inputs.nixpkgs.pkgs) formats;
      generator = formats.toml {};
    in
    inputs.mkWrapper {
      inherit (options) package;
      symlinks = {
        "$out/tealdeer-config/config.toml" =
          if options ? configFile then
            options.configFile
          else if options ? settings then
            generator.generate "config.toml" options.settings
          else
            null;
      };
      environment = {
        TEALDEER_CONFIG_DIR = "$out/tealdeer-config";
      };
    }
  );

  meta = {
    maintainers = [ "es-sai-fi" ];
  };
}
