#!/bin/bash

set +x # Do not leak information

RELEASE_NAME="continuous" # Do not use "latest" as it is reserved by GitHub
FULLNAME=SOME_FILE_NAME

if [ "$TRAVIS_EVENT_TYPE" == "pull_request" ] ; then
  echo "Release uploading disabled for pull requests, TODO: Implement https://transfer.sh/ uploading for these"
  exit 0
fi

if [ ! -z "$TRAVIS_REPO_SLUG" ] ; then
  # We are running on Travis CI
  REPO_SLUG="$TRAVIS_REPO_SLUG"
  if [ -z "$GITHUB_TOKEN" ] ; then
    echo "\$GITHUB_TOKEN missing, please set it in the Travis CI settings of this project"
    echo "You can get one from https://github.com/settings/tokens"
    exit 1
  fi
else
  # We are not running on Travis CI
  echo "Not running on Travis CI"
  if [ -z "$REPO_SLUG" ] ; then
    read -s -p "Repo Slug (GitHub and Travis CI username/reponame): " REPO_SLUG
  fi
  if [ -z "$GITHUB_TOKEN" ] ; then
    read -s -p "Token (https://github.com/settings/tokens): " GITHUB_TOKEN
  fi
fi

echo "Delete the release..."

release_infos=$(curl -GET --silent \
    --header "Authorization: token ${GITHUB_TOKEN}" \
    "https://api.github.com/repos/$REPO_SLUG/releases/tags/$RELEASE_NAME")

# delete_url=$(echo "$release_infos" | grep '"url":' | head -n 1 | cut -d '"' -f 4)

# echo "delete_url: $delete_url"

curl -XDELETE --silent \
    --header "Authorization: token ${GITHUB_TOKEN}" \
    "https://api.github.com/repos/$REPO_SLUG/releases/tags/$RELEASE_NAME"

echo "Delete the tag as well..."

delete_url="https://api.github.com/repos/$REPO_SLUG/git/refs/tags/$RELEASE_NAME"

echo "delete_url: $delete_url"

RESPONSE=$(curl -XDELETE \
    --header "Authorization: token ${GITHUB_TOKEN}" \
    "${delete_url}")

echo "$RESPONSE"

echo "Create release..."

if [ -z "$TRAVIS_BRANCH" ] ; then
  TRAVIS_BRANCH="master"
fi

if [ ! -z "$TRAVIS_JOB_ID" ] ; then
  BODY="Travis CI build log: http://archive.travis-ci.org/jobs/$TRAVIS_JOB_ID/log.txt"
else
  BODY=""
fi

release_infos=$(curl -H "Authorization: token ${GITHUB_TOKEN}" \
     --data '{"tag_name": "'"$RELEASE_NAME"'","target_commitish": "'"$TRAVIS_BRANCH"'","name": "'"Continuous build"'","body": "'"$BODY"'","draft": false,"prerelease": true}' "https://api.github.com/repos/$REPO_SLUG/releases")

echo "$release_infos"

upload_url=$(echo "$release_infos" | grep '"upload_url":' | head -n 1 | cut -d '"' -f 4 | cut -d '{' -f 1)
echo "upload_url: $upload_url"

release_url=$(echo "$release_infos" | grep '"url":' | head -n 1 | cut -d '"' -f 4 | cut -d '{' -f 1)
echo "release_url: $release_url"

echo "Upload binaries to the release..."

for FILE in $@ ; do
  FULLNAME="${FILE}"
  BASENAME="$(basename "${FILE}")"
  curl -H "Authorization: token ${GITHUB_TOKEN}" \
       -H "Accept: application/vnd.github.manifold-preview" \
       -H "Content-Type: application/octet-stream" \
       --data-binary @$FULLNAME \
       "$upload_url?name=$BASENAME"
  echo ""
done

echo "Publish the release..."

release_infos=$(curl -H "Authorization: token ${GITHUB_TOKEN}" \
     --data '{"draft": false}' "$release_url")

echo "$release_infos"
