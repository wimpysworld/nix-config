function switch-home
    if test -e $HOME/Zero/nix-config
        # Get the number of processing units
        set -l all_cores (nproc)
        # Calculate 75% of the number of processing units
        set -l build_cores (math "round(0.75 * ($all_cores))")
        echo "Switch Home Manager with $build_cores cores"
        nh home switch --backup-extension backup ~/Zero/nix-config/ -- --cores $build_cores
    else
        echo "ERROR! No nix-config found in $HOME/Zero/nix-config"
    end
end
