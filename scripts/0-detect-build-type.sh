last_log="$(git log --oneline -n 1)"

mkdir $HOME/gui_build/data

if [ "$( echo "$last_log" | grep "\[STABLE\]" )" ]; then
	echo "Detected STABLE build."
	echo STABLE > $HOME/gui_build/data/type
else
	echo "Detected DEV build."
	echo DEV > $HOME/gui_build/data/type
fi
