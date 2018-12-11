last_log="$(git log --oneline -n 1)"

if [ "$( echo "$last_log" | grep "\[STABLE\]" )" ]; then
	touch ~/.stable
else
	touch ~/.dev
fi
