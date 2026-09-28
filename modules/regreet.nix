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
        Settings to be injected into the wrapped package's configuration.

        See the [ReGreet docs](https://github.com/rharish101/ReGreet/tree/main#configuration) for valid options.

        Disjoint with the `configFile` option.
      '';
    };
    configFile = {
      type = types.pathLike;
      description = ''
        Configuration file to be injected into the wrapped package.

        See the [ReGreet docs](https://github.com/rharish101/ReGreet/tree/main#configuration) for valid options:

        Disjoint with the `settings` option.
      '';
    };
    cssContents = {
      type = types.string;
      description = ''
        GTK4 CSS to be injected into the wrapped package.

        See the [ReGreet docs](https://github.com/rharish101/ReGreet/tree/main#custom-css) for details.

        Disjoint with the `cssFile` option.
      '';
    };
    cssFile = {
      type = types.pathLike;
      description = ''
        GTK4 CSS file to be injected into the wrapped package.

        See the [ReGreet docs](https://github.com/rharish101/ReGreet/tree/main#custom-css) for details.

        Disjoint with the `cssContents` option.
      '';
    };
    extraPackages = {
      type = types.listOf types.derivation;
      description = ''
        Packages to be automatically added to ReGreet's XDG_DATA_DIRS.
        Typically used for GTK4, icon, and cursor themes.
      '';
    };
    fontPackages = {
      type = types.listOf types.derivation;
      description = ''
        Font packages looked up by ReGreet.
      '';
    };
    package = {
      type = types.derivation;
      description = "The ReGreet package to be wrapped.";
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.regreet;
    };
  };

  result = promise (
    { options, inputs }:
    let
      inherit (inputs.nixpkgs.lib) makeSearchPath optionals;
      inherit (inputs.nixpkgs.pkgs) formats makeFontsConf writeText;
      generator = formats.toml {};
    in
    assert !(options ? settings && options ? configFile);
    assert !(options ? cssContents && options ? cssFile);
    inputs.mkWrapper {
      inherit (options) package;
      symlinks = {
        "$out/config.toml" =
          if options ? configFile then
            options.configFile
          else if options ? settings then
            generator.generate "config.toml" options.settings
          else
            null;
        "$out/style.css" =
          if options ? cssFile then
            options.cssFile
          else if options ? cssContents then
            writeText "style.css" options.cssContents
          else
            null;
        "$out/fonts.conf" =
          if options ? fontPackages then
            makeFontsConf { fontDirectories = options.fontPackages; }
          else
            null;
      };
      flags =
        (optionals (options ? configFile || options ? settings) [
          "--config=$out/config.toml"
        ])
        ++ (optionals (options ? cssContents || options ? cssFile) [
          "--style=$out/style.css"
        ]);
      environment = {
        FONTCONFIG_FILE = if options ? fontPackages then "$out/fonts.conf" else null;
      };
      wrapperArgs =
        if options ? extraPackages then
          "--prefix XDG_DATA_DIRS : ${makeSearchPath "share" options.extraPackages}"
        else
          null;
    }
  );

  meta = {
    maintainers = [ "EpicEric" ];
  };
}
