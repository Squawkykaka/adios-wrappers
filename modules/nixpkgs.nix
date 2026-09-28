{ types, promise, ... }:
{
  options = {
    pkgs = {
      type = types.attrs;
    };
    lib = {
      type = types.attrs;
      default = promise ({ options }: options.pkgs.lib);
    };
  };

  meta = {
    maintainers = [ "llakala" ];
  };
}
