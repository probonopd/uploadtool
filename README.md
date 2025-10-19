# uploadtool

Super simple uploading of continuous builds (each push) to GitHub Releases. If this is not the easiest way to upload continuous builds to GitHub Releases, then it is a bug.

## Usage

This script is designed to be called in GitHub Actions after a successful build. By default, this script will _delete_ any pre-existing release tagged with `continuous`, tag the current state with the name `continuous`, create a new release with that name, and upload the specified binaries there. For pull requests, it will upload the binaries to transfersh.com instead and post the resulting download URL to the pull request page on GitHub.

The `GITHUB_TOKEN` is already available in the main branch but it needs to be passes as an environment variable to the script:

```yaml
- name: Upload files
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  run: |
    set -e
    ls -lh out/* # Assuming you have some files in out/ that you would like to upload
    wget -c https://github.com/probonopd/uploadtool/raw/master/upload.sh
    bash upload.sh out/*
```

In case of "Resource not accessible by integration" (403) errors, may also need `permissions: write-all` at the top of the file.

## Environment variables

`upload.sh` normally only creates one stream of continuous releases for the latest commits that are pushed into (or merged into) the repository.

It's possible to use `upload.sh` in a more complex manner by setting the environment variable `UPLOADTOOL_SUFFIX`. If this variable is set to the name of the current tag, then `upload.sh` will upload a release to the repository.

If `UPLOADTOOL_SUFFIX` is set to a different text, then this text is used as suffix for the `continuous` tag that is created for continuous releases. This way, a project can customize what releases are being created.
One possible use case for this is to set up continuous builds for feature or test branches:
```
  if [ ! -z ${GITHUB_HEAD_REF:-$GITHUB_REF_NAME} ] && [ "${GITHUB_HEAD_REF:-$GITHUB_REF_NAME}" != "main" ] ; then
    export UPLOADTOOL_SUFFIX=${GITHUB_HEAD_REF:-$GITHUB_REF_NAME}
  fi
```
This will create builds tagged with `continuous` for pushes / merges to `master` and with `continuous-<branch-name>` for pushes / merges to other branches.

The two environment variables `UPLOADTOOL_PR_BODY` and `UPLOADTOOL_BODY` allow the calling script to customize the messages that are posted either for pull requests or merges / pushes. If these variables aren't set, generic default texts are used.

Set the environment variable `UPLOADTOOL_ISPRERELEASE=true` if you want an untagged release to be marked as pre-release on GitHub.

Note that `UPLOADTOOL*` variables will be used in bash script to form a JSON request, that means some
characters like double quotes and new lines need to be escaped - example: `export UPLOADTOOL_BODY="\\\"Experimental\\\" version.\nDon't use this."`
