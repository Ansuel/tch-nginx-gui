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
