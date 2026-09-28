{ types, promise, ... }:
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

        See the [documentation](https://github.com/Notarin/hayabusa/blob/main/CONFIGURATION.md) for syntax and valid options.

        Disjoint with the `configFile` option.
      '';
    };
    configFile = {
      type = types.pathLike;
      description = ''
        `config.toml` file to be injected into the wrapped package.

        See the [documentation](https://github.com/Notarin/hayabusa/blob/main/CONFIGURATION.md) for syntax and valid options.

        Disjoint with the `settings` option.
      '';
    };

    luaContents = {
      type = types.string;
      description = ''
        Lua code to be injected into the wrapped package's `config.lua`.

        See the [default lua file](https://github.com/Notarin/hayabusa/blob/main/src/config/default.lua) for a general
        idea of expected contents and formatting.

        Disjoint with the `luaFile` option.
      '';
    };
    luaFile = {
      type = types.pathLike;
      description = ''
        `config.lua` file to be injected into the wrapped package.

        See the [default lua file](https://github.com/Notarin/hayabusa/blob/main/src/config/default.lua) for a general
        idea of expected contents and formatting.

        Disjoint with the `luaContents` option.
      '';
    };

    package = {
      type = types.derivation;
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.hayabusa;
      description = "The hayabusa package to be wrapped";
    };
  };

  result = promise (
    { options, inputs }:
    let
      inherit (inputs.nixpkgs) pkgs;
      inherit (inputs.nixpkgs.pkgs) writeText;
      generator = pkgs.formats.toml {};
    in
    inputs.mkWrapper {
      inherit (options) package;
      symlinks = {
        "$out/hayabusa/config.lua" =
          if options ? luaFile then
            options.luaFile
          else if options ? luaContents then
            writeText "config.lua" options.luaContents
          else
            null;
        "$out/hayabusa/config.toml" =
          if options ? configFile then
            options.configFile
          else if options ? settings then
            generator.generate "config.toml" options.settings
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
