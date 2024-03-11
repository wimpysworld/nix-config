function build-home
    if test -e $HOME/Zero/nix-config
        # Get the number of processing units
        set -l all_cores (nproc)
        # Calculate 75% of the number of processing units
        set -l build_cores (math "round(0.75 * ($all_cores))")
        pushd $HOME/Zero/nix-config > /dev/null
        echo "Building Home Manager with $build_cores cores"
        home-manager build --flake $HOME/Zero/nix-config -L --cores $build_cores
        popd > /dev/null
    else
        echo "ERROR! No nix-config found in $HOME/Zero/nix-config"
    end
end
