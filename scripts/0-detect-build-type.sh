#!/bin/bash

branch_name="$(git branch | grep \* | cut -d ' ' -f2)"

if [ ! -f  $HOME/gui_build/data ]; then
	mkdir $HOME/gui_build/data
fi

echo "Detected $branch_name build"

case $branch_name in

  stable)
    echo STABLE > $HOME/gui_build/data/type
    ;;

  preview)
    echo PREVIEW > $HOME/gui_build/data/type
    ;;

  master)
    echo DEV > $HOME/gui_build/data/type
    ;;

  *)
    echo $branch_name > $HOME/gui_build/data/type
    ;;
esac

echo $(git log -1 --abbrev-commit --oneline | cut -d' ' -f1) > $HOME/gui_build/data/short_commit_hash
echo $(git log --oneline -n 1) > $HOME/gui_build/data/last_log
