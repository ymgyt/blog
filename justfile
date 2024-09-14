# Run zola server
serve:
    nix run github:NixOS/nixpkgs/nixpkgs-unstable#zola -- serve --drafts

# Check links
check:
    nix run github:NixOS/nixpkgs/nixpkgs-unstable#zola -- check --drafts
