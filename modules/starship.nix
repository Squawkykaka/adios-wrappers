{ types, promise, assertions, ... } @ adios:
{
  inputs = {
    mkWrapper.from = { parent }: parent.mkWrapper;
    nixpkgs.from = { parent }: parent.nixpkgs;
  };

  options = {
    settings = {
      type = types.attrs;
      description = ''
        Settings to be injected into the wrapped package's `starship.toml`.

        See the [documentation](https://starship.rs/config/) for valid options.

        Disjoint with the `configFile` option.
      '';
    };
    configFile = {
      type = types.pathLike;
      description = ''
        `starship.toml` file to be injected into the wrapped package.

        See the [documentation](https://starship.rs/config/) for valid options.

        Disjoint with the `settings` option.
      '';
    };

    wrapperAttrs = {
      type = types.attrs;
      description = ''
        Attributes to be passed directly to the wrapped package's `mkWrapper` call.

        This is primarily an implementation detail of how the git module mutates the starship wrapper.
        Setting or mutating it yourself isn't recommended.
      '';
      mutators = []; # Hack to make the mergeFunc be called with no mutators
      mergeFunc =
        { mutators, options, inputs }:
        let
          inherit (inputs.nixpkgs.lib) recursiveUpdate;
          inherit (inputs.nixpkgs.pkgs) formats;
          inherit (adios.lib) merge;
          generator = formats.toml {};
          default = {
            inherit (options) package;
            environment.STARSHIP_CONFIG =
              if options ? configFile then
                options.configFile
              else if options ? settings then
                generator.generate "starship.toml" options.settings
              else
                null;
          };
        in
        # Allow mutators to change the default value, with the mutators taking
        # priority if the key is the same
        recursiveUpdate default (merge.attrs.recursively { inherit mutators; });
    };

    package = {
      type = types.derivation;
      default = promise ({ inputs }: inputs.nixpkgs.pkgs.starship);
      description = "The starship package to be wrapped.";
    };
  };

  assertions = [
    (assertions.disjoint "settings" "configFile")
  ];

  mutations = {
    "/fish".interactiveShellInit = promise (
      { options, inputs }:
      let
        finalWrapper = options {};
        inherit (inputs.nixpkgs.lib) getExe;
      in
      # fish
      ''
        ${getExe finalWrapper} init fish --print-full-init \
          | string replace --all "${getExe options.package}" "${getExe finalWrapper}" \
          | source
      ''
    );
  };

  result = promise ({ options, inputs }: inputs.mkWrapper options.wrapperAttrs);

  meta = {
    maintainers = [ "llakala" ];
  };
}
