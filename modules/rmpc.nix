{ types, promise, assertions, ... }:
{
  inputs = {
    nixpkgs.from = { parent }: parent.nixpkgs;
    mkWrapper.from = { parent }: parent.mkWrapper;
  };

  options = {
    configContents = {
      type = types.string;
      description = ''
        Configuration to be injected into the wrapped package's `config.ron`.

        See the [documentation](https://rmpc.mierak.dev/configuration/) on valid options.

        Disjoint with the `configFile` option.
      '';
    };
    configFile = {
      type = types.pathLike;
      description = ''
        `config.ron` file to be injected into the wrapped package.

        See the [documentation](https://rmpc.mierak.dev/configuration/) on valid options.

        Disjoint with the `configContents` option.
      '';
    };

    themes = {
      type = types.attrsOf types.pathLike;
      description = ''
        Themes to be injected into the wrapped package's theme directory.

        See the [documentation](https://rmpc.mierak.dev/configuration/theme/) on valid options.
      '';
    };

    package = {
      type = types.derivation;
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.rmpc;
      description = "The rmpc package to be wrapped.";
    };
  };

  assertions = [
    (assertions.disjoint "configContents" "configFile")
  ];

  result = promise (
    { options, inputs }:
    let
      inherit (inputs.nixpkgs.pkgs) writeText;
      inherit (builtins) attrNames listToAttrs;
      inherit (inputs.nixpkgs.lib) optionalAttrs;
    in
    inputs.mkWrapper {
      inherit (options) package;
      symlinks = {
        "$out/rmpc/config.ron" =
          if options ? configFile then
            options.configFile
          else if options ? configContents then
            writeText "config.ron" options.configContents
          else
            null;
      }
      // optionalAttrs (options ? themes) (
        listToAttrs (
          map (name: {
            name = "$out/rmpc/themes/${name}";
            value = options.themes.${name};
          }) (attrNames options.themes)
        )
      );

      environment = {
        "XDG_CONFIG_HOME" = "$out";
      };
    }
  );

  meta = {
    maintainers = [ "itsyunaya" ];
  };
}
