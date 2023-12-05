# uploadtool

Super simple uploading of continuous builds (each push) to GitHub Releases. If this is not the easiest way to upload continuous builds to GitHub Releases, then it is a bug.

## Usage

This script is designed to be called from Travis CI after a successful build. By default, this script will _delete_ any pre-existing release tagged with `continuous`, tag the current state with the name `continuous`, create a new release with that name, and upload the specified binaries there. For pull requests, it will upload the binaries to transfersh.com instead and post the resulting download URL to the pull request page on GitHub.

**Note: it's recommended to create a separate bot user for uploadtool.** The GitHub token cannot be limited to a single project, so one token will have access to all repositories a user owns. Following the [principle of least privilege](https://en.wikipedia.org/wiki/Principle_of_least_privilege), there should ideally be one user per project ("per organization" will work, too.
GitHub permits every natural user one bot account in the [ToS](https://help.github.com/en/github/site-policy/github-terms-of-service), please make use of it and create one user, ideally for a specific project or organization. *(It's questionable whether GitHub would delete additional such bot accounts, but you shouldn't rely on it.)*

 - On https://github.com/settings/tokens, click on "Generate new token" and generate a token with at least the `public_repo`, `repo:status`, and `repo_deployment` scopes
 - On Travis CI, go to the settings of your project at `https://travis-ci.com/yourusername/yourrepository/settings`
 - Under "Environment Variables", add key `GITHUB_TOKEN` and the token you generated above as the value. **Make sure that "Display value in build log" is set to "OFF"! Also make sure it is only available to your main branch (most of the time, `master`) to avoid leaking it and prevent uploads for any other branches!**
   - Note: if you want to upload tags, too, you must not use this option. Travis doesn't allow for limiting the scope of environment variables to tags, unfortunately.
 - In the `.travis.yml` of your GitHub repository, add something like this (assuming the build artifacts to be uploaded are in out/):

```yaml
after_success:
  - ls -lh out/* # Assuming you have some files in out/ that you would like to upload
  - wget -c https://github.com/probonopd/uploadtool/raw/master/upload.sh
  - bash upload.sh out/*

branches:
  except:
    - # Do not build tags that we create when we upload to GitHub Releases
    - /^(?i:continuous.*)$/
```

It is also possible to use this script with GitHub actions. The `GITHUB_TOKEN` is already available in the main branch but it needs to be passes as an environment variable to the script:

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

## Environment variables

`upload.sh` normally only creates one stream of continuous releases for the latest commits that are pushed into (or merged into) the repository.

It's possible to use `upload.sh` in a more complex manner by setting the environment variable `UPLOADTOOL_SUFFIX`. If this variable is set to the name of the current tag, then `upload.sh` will upload a release to the repository (basically reproducing the `deploy:` feature in `.travis.yml`).

If `UPLOADTOOL_SUFFIX` is set to a different text, then this text is used as suffix for the `continuous` tag that is created for continuous releases. This way, a project can customize what releases are being created.
One possible use case for this is to set up continuous builds for feature or test branches:
```
  if [ ! -z $TRAVIS_BRANCH ] && [ "$TRAVIS_BRANCH" != "master" ] ; then
    export UPLOADTOOL_SUFFIX=$TRAVIS_BRANCH
  fi
```
This will create builds tagged with `continuous` for pushes / merges to `master` and with `continuous-<branch-name>` for pushes / merges to other branches.

The two environment variables `UPLOADTOOL_PR_BODY` and `UPLOADTOOL_BODY` allow the calling script to customize the messages that are posted either for pull requests or merges / pushes. If these variables aren't set, generic default texts are used.

Set the environment variable `UPLOADTOOL_ISPRERELEASE=true` if you want an untagged release to be marked as pre-release on GitHub.

Note that `UPLOADTOOL*` variables will be used in bash script to form a JSON request, that means some
characters like double quotes and new lines need to be escaped - example: `export UPLOADTOOL_BODY="\\\"Experimental\\\" version.\nDon't use this.\nTravis CI build log: https://travis-ci.com/$TRAVIS_REPO_SLUG/builds/$TRAVIS_BUILD_ID/"`
