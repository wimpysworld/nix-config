function switch-home
    if test -e $HOME/Zero/nix-config
        pushd $HOME/Zero/nix-config
        home-manager switch -b backup --flake $HOME/Zero/nix-config
        popd
    else
        echo "ERROR! No nix-config found in $HOME/Zero/nix-config"
    end
end
