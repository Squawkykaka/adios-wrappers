{ types, promise, assertions, ... }:
{
  inputs = {
    mkWrapper.from = { parent }: parent.mkWrapper;
    nixpkgs.from = { parent }: parent.nixpkgs;
  };

  options = {
    configFiles = {
      type = types.attrsOf types.pathLike;
      description = ''
        Anyrun and plugin config files to be injected into the wrapped package.

        See the [config example](https://github.com/anyrun-org/anyrun/blob/master/examples/config.ron) for valid anyrun options and the [plugins directory](https://github.com/anyrun-org/anyrun/tree/master/plugins) for official plugins.
      '';
      example = ''
        {
          config.ron = ./config.ron;
          shell.ron = ./shell.ron;
        }'';
    };

    cssContents = {
      type = types.string;
      description = ''
        CSS to be injected into the wrapped package.

        Refer to the [example stylesheet](https://github.com/anyrun-org/anyrun/blob/master/anyrun/res/style.css) for possible configuration.

        Disjoint with the `cssFile` option.
      '';
    };
    cssFile = {
      type = types.pathLike;
      description = ''
        `style.css` file to be injected into the wrapped package.

        Refer to the [example stylesheet](https://github.com/anyrun-org/anyrun/blob/master/anyrun/res/style.css) for possible configuration.

        Disjoint with the `cssContents` option.
      '';
    };

    pluginPaths = {
      type = types.listOf types.pathLike;
      description = ''
        Paths of anyrun plugins to be installed into the plugins directory.

        Must point to a plugin's shared object file (`.so`).
      '';
      example = ''
        [
          "''${inputs.nixpkgs.pkgs.anyrun}/lib/libapplications.so"
          ./my-plugins/libshell.so
        ]'';
    };

    package = {
      type = types.derivation;
      default = promise ({ inputs }: inputs.nixpkgs.pkgs.anyrun);
      description = "The anyrun package to be wrapped.";
    };
  };

  assertions = [
    (assertions.disjoint "cssContents" "cssFile")
  ];

  result = promise (
    { options, inputs }:
    let
      inherit (inputs.nixpkgs.pkgs) writeText;
      inherit (builtins) attrNames baseNameOf listToAttrs unsafeDiscardStringContext;
      inherit (inputs.nixpkgs.lib) optionalAttrs;
    in
    inputs.mkWrapper {
      inherit (options) package;
      symlinks = {
        "$out/anyrun/style.css" =
          if options ? cssFile then
            options.cssFile
          else if options ? cssContents then
            writeText "style.css" options.cssContents
          else
            null;
      }
      // optionalAttrs (options ? configFiles) (
        listToAttrs (
          map (file: {
            name = "$out/anyrun/${file}";
            value = options.configFiles.${file};
          }) (attrNames options.configFiles)
        )
      )
      // optionalAttrs (options ? pluginPaths) (
        listToAttrs (
          map (plugin: {
            # We need to use ctx discard, since Nix doesn't allow str contexts to have a value here.
            # The context is present in the first place because the string may point to a store path.
            # (see the manual entry on string context for more info)
            # Safe because the context isn't used here at all.
            name = "$out/anyrun/plugins/${unsafeDiscardStringContext (baseNameOf plugin)}";
            value = plugin;
          }) options.pluginPaths
        )
      );

      flags = [
        "--config-dir"
        "$out/anyrun"
      ];
    }
  );

  meta = {
    maintainers = [ "itsyunaya" ];
  };
}
