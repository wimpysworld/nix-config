function gpg-restore
    mkdir -p --mode 700 $HOME/.gnupg
    gpgconf --kill gpg-agent

    if test (uname) = "Darwin"
        set base_temp_dir (getconf DARWIN_USER_TEMP_DIR)/secrets.d/

        if test -d $base_temp_dir
            set temp_dir (find $base_temp_dir -type d -maxdepth 1 -exec basename {} \; | sort -n | tail -n 1)
            set temp_dir $base_temp_dir$temp_dir
        else
            echo "Directory $base_temp_dir does not exist."
            return 1
        end
    else
        set temp_dir /run/user/(id -u)/secrets
    end

    if test -d $temp_dir
        gpg --import --batch $temp_dir/gpg_private
        gpg --import $temp_dir/gpg_public
        gpg --list-secret-keys
        gpg --list-keys
        gpg --import-ownertrust $temp_dir/gpg_ownertrust
    else
        echo "Secrets directory $temp_dir does not exist."
        return 1
    end
end
