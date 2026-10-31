{ ... }: {

  home.sessionVariables = {
    EDITOR = "nixvim-editor";
    # RTK (token compression) is opt-in only: use `oprtk` (see fish.nix).
    RTK_DISABLED = "1";
  };
}
