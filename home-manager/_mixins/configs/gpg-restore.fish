function gpg-restore
    mkdir -p --mode 700 $HOME/.gnupg
    gpgconf --kill gpg-agent
    gpg --import --batch /run/user/(id -u)/secrets/gpg_private
    gpg --import /run/user/(id -u)/secrets/gpg_public
    gpg --list-secret-keys
    gpg --list-keys
    gpg --import-ownertrust /run/user/(id -u)/secrets/gpg_ownertrust
end
