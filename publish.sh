#!/bin/bash -e
# This script publishes the GraphQL specification document to the web.

# Determine if this is a tagged release
GITTAG=$(git tag --points-at HEAD)

# Build the specification document into publishable form
echo "Building spec"
mkdir -p out
if [ -n "$GITTAG" ]; then
  spec-md --metadata spec/metadata.json --githubSource "https://github.com/graphql/graphql-spec/blame/$GITTAG/" spec/GraphQL.md > out/index.html
else
  spec-md --metadata spec/metadata.json --githubSource "https://github.com/graphql/graphql-spec/blame/main/" spec/GraphQL.md > out/index.html
fi
npm run build > /dev/null 2>&1

# Check out gh-pages locally.
echo "Cloning gh-pages"
rm -rf gh-pages
git clone -b gh-pages "https://${GH_TOKEN}@github.com/graphql/graphql-spec.git" gh-pages > /dev/null 2>&1

# Replace /draft with this build.
echo "Publishing to: /draft"
rm -rf gh-pages/draft
cp -R out/ gh-pages/draft

# If this is a tagged commit, publish to a permalink and index.
if [ -n "$GITTAG" ]; then
  echo "Publishing to: /$GITTAG"
  cp -R out/ "gh-pages/$GITTAG"
fi

# Create the index file
echo "Rebuilding: / (index)"
HTML="<html>
  <head>
    <title>GraphQL Specification Versions</title>
    <style>
      body {
        color: #333333;
        font: 13pt/18pt Cambria, 'Palatino Linotype', Palatino, 'Liberation Serif', serif;
        margin: 6rem auto 3rem;
        max-width: 780px;
      }
      @media (min-width: 1240px) {
        body {
          padding-right: 300px;
        }
      }
      a {
        color: #3B5998;
        text-decoration: none;
      }
      a:hover {
        text-decoration: underline;
      }
      h1 {
        font-size: 1.5em;
        margin: 8rem 0 2em;
      }
      td {
        padding-bottom: 5px;
      }
      td + td {
        padding-left: 2ch;
      }
    </style>
  </head>
  <body>
    <h1>GraphQL</h1>
    <table>"

# Include latest draft
GITDATE=$(git show -s --format=%cd --date=format:"%a, %b %-d, %Y" HEAD)
HTML="$HTML
    <tr>
      <td><em>Prerelease</em></td>
      <td><a href=\"./draft\" keep-hash>Working Draft</a></td>
      <td>$GITDATE</td>
      <td></td>
    </tr>"

GITHUB_RELEASES="https://github.com/graphql/graphql-spec/releases/tag"
for GITTAG in $(git tag -l --sort='-*committerdate') ; do
  VERSIONYEAR=${GITTAG: -4}
  TAGTITLE="${GITTAG%$VERSIONYEAR} $VERSIONYEAR"
  TAGGEDCOMMIT=$(git rev-list -1 "$GITTAG")
  GITDATE=$(git show -s --format=%cd --date=format:"%a, %b %-d, %Y" $TAGGEDCOMMIT)

  HTML="$HTML
    <tr>"

  [ -z $HAS_LATEST_RELEASE ] && HTML="$HTML
      <td><em>Latest Release</em></td>" || HTML="$HTML
      <td></td>"
  HAS_LATEST_RELEASE=1

  HTML="$HTML
      <td><a href=\"./$GITTAG\" keep-hash>$TAGTITLE</a></td>
      <td>$GITDATE</td>
      <td><a href=\"$GITHUB_RELEASES/$GITTAG\">Release Notes</a></td>
    </tr>"
done

HTML="$HTML
    </table>
    <script>
      var links = document.getElementsByTagName('a');
      for (var i = 0; i < links.length; i++) {
        if (links[i].hasAttribute('keep-hash')) {
          links[i].href += location.hash;
          links[i].removeAttribute('keep-hash');
        }
      }
    </script>
  </body>
</html>"

echo $HTML > "gh-pages/index.html"

echo "Pushing update"
cd gh-pages
git config user.name "Travis CI"
git config user.email "github@fb.com"
git add -A .
if git diff --staged --quiet; then
  echo "Nothing to publish"
else
  git commit -a -m "Deploy to GitHub Pages"
  git push > /dev/null 2>&1
  echo "Pushed"
fi
