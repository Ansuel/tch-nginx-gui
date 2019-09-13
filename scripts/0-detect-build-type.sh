branch_name="$(git branch | grep \* | cut -d ' ' -f2)"

if [ ! -f  $HOME/gui_build/data ]; then
	mkdir $HOME/gui_build/data
fi

if [ "$( echo "$branch_name" | grep "stable" )" ]; then
	echo "Detected STABLE build."
	echo STABLE > $HOME/gui_build/data/type
elif [ "$( echo "$branch_name" | grep "preview" )" ]; then
	echo "Detected PREVIEW build."
	echo PREVIEW > $HOME/gui_build/data/type
else
	echo "Detected DEV build."
	echo DEV > $HOME/gui_build/data/type
fi

echo $(git log -1 --abbrev-commit --oneline | cut -d' ' -f1) > $HOME/gui_build/data/short_commit_hash
echo $(git log --oneline -n 1) > $HOME/gui_build/data/last_log
