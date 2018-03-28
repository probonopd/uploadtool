#!/bin/bash

set +x # Do not leak information

RELEASE_NAME="$1" # Do not use "latest" as it is reserved by GitHub
shift
FULLNAME=SOME_FILE_NAME

#__________________________________________________________
#
# INITIALIZATION
#__________________________________________________________

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
    

#__________________________________________________________
#
# Retrieve the "Continuous builds" release ID
# create the release if missing
#__________________________________________________________

release_url="https://api.github.com/repos/$REPO_SLUG/releases/tags/$RELEASE_NAME"
echo "Getting the release ID..."
echo "release_url: $release_url"
release_infos=$(curl -XGET --header "Authorization: token ${GITHUB_TOKEN}" "${release_url}")
release_id=$(echo "$release_infos" | grep '"id":' | head -n 1 | tr -s " " | cut -f 3 -d" " | cut -f 1 -d ",")
echo "release ID: $release_id"

if [ x"$release_id" == "x" ]; then

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
fi
  
echo "$release_infos"
release_id=$(echo "$release_infos" | grep '"id":' | head -n 1 | tr -s " " | cut -f 3 -d" " | cut -f 1 -d ",")
echo "release ID: $release_id"

upload_url=$(echo "$release_infos" | grep '"upload_url":' | head -n 1 | cut -d '"' -f 4 | cut -d '{' -f 1)
echo "upload_url: $upload_url"

release_url=$(echo "$release_infos" | grep '"url":' | head -n 1 | cut -d '"' -f 4 | cut -d '{' -f 1)
echo "release_url: $release_url"

#__________________________________________________________
#
# List assets in the release
#__________________________________________________________

assets_url="https://api.github.com/repos/$REPO_SLUG/releases/$release_id/assets"
release_assets=$(curl -XGET --header "Authorization: token ${GITHUB_TOKEN}" "${assets_url}")

echo "Assets:"
echo "$release_assets"

assets_ids=$(echo "$release_assets" | grep '"id":')
echo "Asset IDs:"
echo "$assets_ids"

Nassets=$(echo "$assets_ids" | wc -l)
for aid in $(seq 1 2 $Nassets); do
    id=$(echo "$assets_ids" | sed -n ${aid}p | tr -s " " | cut -f 3 -d" " | cut -f 1 -d ",")
    echo "Asset id: $id"
    asset_url="https://api.github.com/repos/$REPO_SLUG/releases/assets/$id"
    echo "asset_url: $asset_url"
    asset_info=$(curl -XGET --header "Authorization: token ${GITHUB_TOKEN}" "${asset_url}")
    echo "$asset_info" | grep "browser_download_url"
    for FILE in $@ ; do
        FULLNAME="${FILE}"
        BASENAME="$(basename "${FILE}")"
	test=$(echo "$asset_info" | grep "browser_download_url" | grep "$BASENAME")
	if [ -n "$test" ]; then
	    curl -XDELETE --header "Authorization: token ${GITHUB_TOKEN}" "${asset_url}"
	fi
    done
done


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
