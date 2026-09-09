WEAVE_PASSWORD=$(<"${CREDENTIALS_DIRECTORY}/password")
: "${WEAVE_PASSWORD:?The Weave password must not be empty.}"
export WEAVE_PASSWORD
exec weave
