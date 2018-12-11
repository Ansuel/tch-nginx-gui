last_log="$(git log --oneline -n 1)"

if [ "$( echo "$last_log" | grep "\[STABLE\]" )" ]; then
	echo "Detected STABLE build."
	touch ~/.stable
else
	echo "Detected DEV build."
	touch ~/.dev
fi
