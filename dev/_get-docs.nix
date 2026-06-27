let
  inherit (builtins) getFlake attrNames concatMap listToAttrs;
  modules = (getFlake (toString ../.)).wrapperModules;

  sources = import ./npins;
  lib = import (sources.nixpkgs + "/lib");
  toPretty = lib.generators.toPretty {
    multiline = true;
    allowPrettyValues = true;
  };

  makeText = thing: {
    _type = "literalExpression";
    text = toPretty thing;
  };
in
listToAttrs (
  concatMap (
    wrapperName:
    let
      wrapper = modules.${wrapperName}.options;
    in
    map (
      optionName:
      let
        option = wrapper.${optionName};
      in {
        name = "${wrapperName}.${optionName}";
        value = {
          declarations = [
            {
              name = "adios-wrappers/modules/${wrapperName}.nix";
              url = "https://github.com/llakala/adios-wrappers/blob/main/modules/${wrapperName}.nix";
            }
          ];
          ${if option ? defaultText || option ? default then "default" else null} = makeText (
            if option ? default then option.default else option.defaultText
          );
          ${if option ? example then "example" else null} = makeText option.example;
          ${if option ? description then "description" else null} = option.description;
          loc = [
            wrapperName
            optionName
          ];
          readOnly = false;
          type = option.type.name;
        };
      }
    ) (attrNames wrapper)
  ) (attrNames modules)
)
