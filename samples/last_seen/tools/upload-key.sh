#!/usr/bin/env bash
# Encrypts or restores the Play upload key: android/key.properties and android/app/upload-keystore.jks, both
# git-ignored, packed into android/upload-key.tar.enc, which is committed. AES-256 with PBKDF2 through openssl.
#
#   samples/last_seen/tools/upload-key.sh decrypt    restore the key before `make release-last-seen`
#   samples/last_seen/tools/upload-key.sh encrypt    after making or rotating the key
#
# The passphrase comes from $LAST_SEEN_KEY_PASSPHRASE, else from the file named by $LAST_SEEN_KEY_PASSFILE, else
# openssl asks for it. It lives only in the owner's password manager (and a CI secret, if CI ever signs).
set -euo pipefail

android=$(cd "$(dirname "$0")/../android" && pwd)
blob="$android/upload-key.tar.enc"
files=(key.properties app/upload-keystore.jks)
crypt=(openssl enc -aes-256-cbc -pbkdf2 -iter 600000 -md sha256)

pass=()
if [[ -n ${LAST_SEEN_KEY_PASSPHRASE:-} ]]; then
  pass=(-pass env:LAST_SEEN_KEY_PASSPHRASE)
elif [[ -n ${LAST_SEEN_KEY_PASSFILE:-} ]]; then
  pass=(-pass "file:$LAST_SEEN_KEY_PASSFILE")
fi

case "${1:-}" in
  encrypt)
    for f in "${files[@]}"; do [[ -f "$android/$f" ]] || { echo "missing android/$f" >&2; exit 1; }; done
    COPYFILE_DISABLE=1 tar -C "$android" -cf - "${files[@]}" | "${crypt[@]}" -salt "${pass[@]}" -out "$blob"
    echo "saved $blob"
    ;;
  decrypt)
    for f in "${files[@]}"; do
      [[ ! -e "$android/$f" ]] || { echo "android/$f already exists, move it aside first" >&2; exit 1; }
    done
    "${crypt[@]}" -d "${pass[@]}" -in "$blob" | tar -C "$android" -xf -
    echo "restored ${files[*]} in $android"
    ;;
  *)
    echo "usage: $0 encrypt|decrypt" >&2
    exit 64
    ;;
esac
