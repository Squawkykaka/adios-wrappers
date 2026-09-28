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
        Settings to be injected into the wrapped package's `alacritty.toml`.

        See the alacritty [documentation](https://alacritty.org/config-alacritty.html).

        Disjoint with the `configFile` option.
      '';
    };
    configFile = {
      type = types.pathLike;
      description = ''
        `alacritty.toml` file to be injected into the wrapped package.

        See the alacritty [documentation](https://alacritty.org/config-alacritty.html).

        Disjoint with the `settings` option.
      '';
    };

    package = {
      type = types.derivation;
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.alacritty;
      description = "The alacritty package to be wrapped.";
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
        "$out/alacritty/alacritty.toml" =
          if options ? configFile then
            options.configFile
          else if options ? settings then
            generator.generate "alacritty.toml" options.settings
          else
            null;
      };
      flags = [
        "--config-file"
        "$out/alacritty/alacritty.toml"
      ];
    }
  );

  meta = {
    maintainers = [ "es-sai-fi" ];
  };
}
