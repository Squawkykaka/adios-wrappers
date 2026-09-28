{ types, promise, ... }:
{
  inputs = {
    mkWrapper.from = { parent }: parent.mkWrapper;
    nixpkgs.from = { parent }: parent.nixpkgs;
  };

  options = {
    color = {
      type = types.string;
      description = "Hex formatted background color to be displayed by the wrapped package.";
      example = "ffffff";
    };
    backgroundImage = {
      type = types.pathLike;
      description = "Path to the background image to be displayed by the wrapped package.";
    };
    scalingMode = {
      type = types.string;
      description = ''
        Mode to determine how the wrapped package scales images.

        See the [documentation](https://man.archlinux.org/man/extra/swaybg/swaybg.1.en#OPTIONS) for valid modes.
      '';
    };
    outputName = {
      type = types.string;
      description = "Name of the output to be used by the wrapped package.";
      example = "eDP-1";
    };

    package = {
      type = types.derivation;
      default = promise ({ inputs }: inputs.nixpkgs.pkgs.swaybg);
      description = "The swaybg package to be wrapped.";
    };
  };

  result = promise (
    { options, inputs }:
    let
      inherit (inputs.nixpkgs.lib) optionals;
    in
    inputs.mkWrapper {
      inherit (options) package;
      symlinks = {
        # Unnecessary as `backgroundImage` can be passed directly to `-i` but this assists with debugging.
        "$out/backgroundImage" = options.backgroundImage or null;
      };
      flags =
        (optionals (options ? color) [
          "-c"
          options.color
        ])
        ++ (optionals (options ? backgroundImage) [
          "-i"
          "$out/backgroundImage"
        ])
        ++ (optionals (options ? scalingMode) [
          "-m"
          options.scalingMode
        ])
        ++ (optionals (options ? outputName) [
          "-o"
          options.outputName
        ]);
    }
  );

  meta = {
    maintainers = [];
  };
}
