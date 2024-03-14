# Run zola server
serve:
    nix run nixpkgs#zola -- serve --drafts

# Check links
check:
    nix run nixpkgs#zola -- check --drafts
