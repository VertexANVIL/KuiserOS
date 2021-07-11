{ lib, ... }: rec {
    inherit (builtins) attrNames isAttrs isList elem listToAttrs hasAttr mapAttrs;

    inherit (lib) all head tail last unique length nameValuePair genList genAttrs zipAttrsWith zipAttrsWithNames
        optionalAttrs filterAttrs mapAttrs' mapAttrsToList setAttrByPath concatLists concatMap foldl' elemAt;

    # mapFilterAttrs ::
    #   (name -> value -> bool )
    #   (name -> value -> { name = any; value = any; })
    #   attrs
    mapFilterAttrs = seive: f: attrs: filterAttrs seive (mapAttrs' f attrs);

    # Generate an attribute set by mapping a function over a list of values.
    genAttrs' = values: f: listToAttrs (map f values);

    # counts the number of attributes in a set
    attrCount = set: length (attrNames set);

    defaultAttrs = attrs: default: f: if attrs != null then f attrs else default;

    # given a list of attribute sets, merges the keys specified by "names" from "defaults" into them if they do not exist
    defaultSetAttrs = sets: names: defaults: (mapAttrs' (n: v: nameValuePair n (
        v // genAttrs names (name: (if hasAttr name v then v.${name} else defaults.${name}) )
    )) sets);

    # maps attrs to list with an extra i iteration parameter
    imapAttrsToList = f: set: (
    let
        keys = attrNames set;
    in
    genList (n:
        let
            key = elemAt keys n;
            value = set.${key};
        in 
        f n key value
    ) (length keys));

    # Recursively merges attribute sets **and** lists
    recursiveMerge = attrList: let f = attrPath: zipAttrsWith (n: values:
        if tail values == [] then head values
        else if all isList values then unique (concatLists values)
        else if all isAttrs values then f [n] values
        else last values
    ); in f [] attrList;

    recursiveMergeAttrsWithNames = names: f: sets:
        zipAttrsWithNames names (name: vs: foldl' f { } vs) sets;

    recursiveMergeAttrsWith = f: sets:
        recursiveMergeAttrsWithNames (concatMap attrNames sets) f sets;
}