if [ -z $MAKEFILE ]; then
    MAKEFILE=Makefile
fi

if [ -z $GITLAB_DOMAIN ]; then
    GITLAB_DOMAIN="gitlab.com"
fi

GITLAB_DOMAIN="framagit.org"
PROJECT_ID="90566"
REPO="ppom/reaction"

current_version=$(cat $MAKEFILE | grep PKG_VERSION | head -n 1 | cut -d "=" -f 2)
current_hash=$(cat $MAKEFILE | grep PKG_HASH | head -n 1 | cut -d "=" -f 2)
echo "Current version: $current_version"
echo "Current hash: $current_hash"

url="https://$GITLAB_DOMAIN/api/v4/projects/$PROJECT_ID/releases/permalink/latest?include_html_description=false"
resp=$(curl -L -s "$url")
latest_version=$(printf '%s' "$resp" | jq -r '.name')
if [ $latest_version = "null" ]; then
    echo "No release found"
    exit 0
fi

echo "Latest version: $latest_version"
latest_version_number=$(echo $latest_version | cut -d "v" -f 2)
echo "Latest version number: $latest_version_number"

if [ -z $SOURCE_URL ]; then
    SOURCE_URL="https://$GITLAB_DOMAIN/$REPO/-/archive/$latest_version/reaction-$latest_version.tar.gz"
else
    SOURCE_URL=$(echo $SOURCE_URL | sed "s/{{version}}/$latest_version_number/g")
fi

wget $SOURCE_URL -O output.tar.gz
hash=$(sha256sum output.tar.gz | cut -d " " -f 1)
echo "New hash: $hash"
echo "Current hash: $current_hash"
rm output.tar.gz

if [ $current_hash = $hash ]; then
    echo "Hash not changed"
    exit 0
fi

exit 0

echo "Update to $latest_version"
sed -i "s/PKG_VERSION:=.*/PKG_VERSION:=$latest_version_number/g" $MAKEFILE
sed -i "s/PKG_RELEASE:=.*/PKG_RELEASE:=1/g" $MAKEFILE
sed -i "s/PKG_HASH:=.*/PKG_HASH:=$hash/g" $MAKEFILE

git config user.name "bot"
git config user.email "bot@github.com"
git add .
if [ -z "$(git status --porcelain)" ]; then
    echo "No changes to commit"
    exit 0
fi

if [ -z $BRANCH ]; then
    BRANCH=main
fi

git commit -m "Bump $REPO to $latest_version"

git push "https://x-access-token:$COMMIT_TOKEN@github.com/$GITHUB_REPOSITORY" HEAD:$BRANCH
