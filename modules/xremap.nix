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
        Settings to be injected into the wrapped package's configuration.

        See the [xremap docs](https://github.com/xremap/xremap#configuration) for valid options.

        Disjoint with the `configFile` option.
      '';
    };
    configFile = {
      type = types.pathLike;
      description = ''
        Configuration file to be injected into the wrapped package.

        See the [xremap docs](https://github.com/xremap/xremap#configuration) for valid options.

        Disjoint with the `settings` option.
      '';
    };
    flags = {
      type = types.listOf types.string;
      description = ''
        Flags to be appended by default when running xremap.

        See the [xremap docs](https://github.com/xremap/xremap/tree/master#commandline-arguments) for valid options.
      '';
    };
    package = {
      type = types.derivation;
      description = ''
        The xremap package to be wrapped.
        Note that this should match the version for your desktop environment or compositor.
      '';
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.xremap;
    };
  };

  assertions = [
    (assertions.disjoint "settings" "configFile")
  ];

  result = promise (
    { options, inputs }:
    let
      inherit (inputs.nixpkgs.lib) optionals;
      inherit (inputs.nixpkgs.pkgs) formats;
      generator = formats.yaml {};
    in
    inputs.mkWrapper {
      inherit (options) package;
      symlinks = {
        "$out/config.yml" =
          if options ? configFile then
            options.configFile
          else if options ? settings then
            generator.generate "config.yml" options.settings
          else
            null;
      };
      flags =
        (options.flags or [])
        ++ (optionals (options ? configFile || options ? settings) [
          "$out/config.yml"
        ]);
    }
  );

  meta = {
    maintainers = [ "EpicEric" ];
  };
}
