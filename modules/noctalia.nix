{ types, promise, ... } @ adios:
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

        See the noctalia docs for valid options:
        https://docs.noctalia.dev/v5

        Disjoint with the `configFile` option.
      '';
      mergeFunc = adios.lib.merge.attrs.recursively;
    };
    configFile = {
      type = types.pathLike;
      description = ''
        `config.toml` file to be injected into the wrapped package.

        See the noctalia docs for valid options:
        https://docs.noctalia.dev/v5

        Disjoint with the `settings` option.
      '';
    };
    package = {
      type = types.derivation;
      description = "The noctalia package to be wrapped.";
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.noctalia;
    };
  };

  result = promise (
    { options, inputs }:
    let
      generator = inputs.nixpkgs.pkgs.formats.toml {};
    in
    assert !(options ? settings && options ? configFile);
    inputs.mkWrapper {
      inherit (options) package;
      symlinks = {
        "$out/noctalia/noctalia.toml" =
          if options ? configFile then
            options.configFile
          else if options ? settings then
            generator.generate "noctalia.toml" options.settings
          else
            null;
      };
      environment = {
        NOCTALIA_CONFIG_HOME = "$out";
      };
    }
  );

  meta = {
    maintainers = [
      "EpicEric"
      "pengo"
    ];
  };
}
