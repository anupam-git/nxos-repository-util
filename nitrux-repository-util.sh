#! /bin/bash


server_url="https://repo.nxos.org/"
repo=nitrux


test "$APTLY_USERNAME" -a "$APTLY_API_KEY" || {
    echo "please set 'APTLY_USERNAME' and 'APTLY_API_KEY' before uploading files."
    echo "ask luis for them."
    exit 1
}


for f; do
    test -f "$f" || {
        echo "'$f' is not a file. aborting."
        echo "usage: ${0##*/} <files>"
        exit 1
    }
done


echo "deleting remote upload directory."
curl -A "mozilla" \
    -X DELETE \
    -sS -u"$APTLY_USERNAME:$APTLY_API_KEY" \
    "$server_url"/aptly-api/files/upload-tmp


for f; do set -- "$@" -F file="@$f"; shift; done

echo "uploading files."
curl -A "mozilla" \
    -sS -u"$APTLY_USERNAME:$APTLY_API_KEY" \
    -X POST "$@" \
    "$server_url"/aptly-api/files/upload-tmp


echo "adding files to $repo."
curl -A "mozilla" \
    -sS -u"$APTLY_USERNAME:$APTLY_API_KEY" \
    -X POST \
    "$server_url"/aptly-api/repos/"$repo"/file/upload-tmp


echo "updating repository $repo..."
curl -A "mozilla" \
    -sS -u"$APTLY_USERNAME:$APTLY_API_KEY" \
    -X PUT \
    -H 'Content-Type: application/json' \
    --data '{ "SourceKind": "local" }' \
    "$server_url"/aptly-api/publish/"$repo"/nitrux


echo "done."
