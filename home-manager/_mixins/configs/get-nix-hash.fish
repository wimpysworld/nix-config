function get-nix-hash
    nix hash to-sri --type sha256 (nix-prefetch-url --unpack "$argv[1]")
end
