
cd $HOME/gui_build

git commit -m "[ci skip]: translation: update po file automatically" decompressed/gui_file/www/lang/*;
git push origin master;

echo "Done.";
