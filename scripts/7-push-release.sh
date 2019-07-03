
DIR="$HOME/gui_build/compressed"
VERSION="$(cat $HOME/gui_build/data/version)"
TYPE="$(cat $HOME/gui_build/data/type)"
if [ $TYPE == "DEV" ] || [ $TYPE == "PREVIEW" ]; then
	PRERELEASE="-prerelease"
fi

ghr -t ${GITHUB_TOKEN} -u ${CIRCLE_PROJECT_USERNAME} -r ${CIRCLE_PROJECT_REPONAME} -c ${CIRCLE_SHA1} $PRERELEASE -delete "$VERSION" "$DIR"