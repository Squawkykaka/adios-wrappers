let
  inherit (builtins) mapAttrs getFlake;
  optionalAttrs = cond: attrs: if cond then attrs else {};
in
mapAttrs (
  _: wrapper:
  {
    options = 
      mapAttrs (
        _: option:
        (removeAttrs option [
          "defaultFunc"
          "mergeFunc"
        ])
        // {
          type = option.type.name;
        }
        // optionalAttrs (option ? mutatorType) {
          mutatorType = option.mutatorType.name;
        }
      ) wrapper.options;
    ${if wrapper ? mutations then "mutations" else null} = builtins.attrNames wrapper.mutations;
  }
) (getFlake (toString ../.)).wrapperModules
