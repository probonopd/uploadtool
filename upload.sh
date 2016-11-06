#!/bin/bash

RELEASE_NAME="latest"
FULLNAME=SOME_FILE_NAME

if [ "$TRAVIS_EVENT_TYPE" == "pull_request" ] ; then
  echo "Release uploading disabled for pull requests, TODO: Implement https://transfer.sh/ uploading for these"
  exit 1
fi

if [ ! -z "$TRAVIS_REPO_SLUG" ] ; then
  # We are running on Travis CI
  REPO_SLUG="$TRAVIS_REPO_SLUG"
  if [ -z "$GITHUB_TOKEN" ] ; then
    echo "$GITHUB_TOKEN missing, please set it in the Travis CI settings of this project"
    echo "You can get one from https://github.com/settings/tokens"
    exit 1
  fi
else
  # We are not running on Travis CI
  echo "Not running on Travis CI, this is currently not supported"
  REPO_SLUG="probonopd/uploadtool"
  if [ -z "$GITHUB_TOKEN" ] ; then
    read -s -p "Token (https://github.com/settings/tokens): " GITHUB_TOKEN
  fi
fi

delete_url="https://api.github.com/repos/$REPO_SLUG/git/refs/tags/$RELEASE_NAME"

#delete_url=$(curl -GET --silent \
#    --header "Authorization: token ${GITHUB_TOKEN}" \
#    "${tag_url}" | grep '"url":' | head -n 1 | cut -d '"' -f 4 )

echo "delete_url: $delete_url"

curl -XDELETE --silent \
    --header "Authorization: token ${GITHUB_TOKEN}" \
    "${delete_url}"

release_url="https://api.github.com/repos/$REPO_SLUG/releases/$RELEASE_NAME"
curl -H "Authorization: token ${GITHUB_TOKEN}" \
     --data '{"tag_name": "'"$RELEASE_NAME"'","target_commitish": "master","name": "'"$RELEASE_NAME"'","body": "'"$RELEASE_NAME"'","draft": false,"prerelease": true}' "https://api.github.com/repos/$REPO_SLUG/releases"

curl -H "Authorization: token ${GITHUB_TOKEN}" \
     -H "Accept: application/vnd.github.manifold-preview" \
     -H "Content-Type: application/octet-stream" \
     --data-binary @$FULLNAME \
     "https://uploads.github.com/repos/$REPO_SLUG/releases/$RELEASE_NAME/assets?name=$FULLNAME"
