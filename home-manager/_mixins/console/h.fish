function h
    set _h_dir (command h --resolve "$HOME/Development" $argv)
    set _h_ret $status

    if test "$_h_dir" != "$PWD"
        cd "$_h_dir"
    end

    return $_h_ret
end
