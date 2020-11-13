git config --global user.name "CircleCI";
git config --global user.email "CircleCI";

ssh -o StrictHostKeyChecking=no git@github.com

cd $HOME/gui_build

git add decompressed/gui_file/www/lang/*
git commit -F- <<EOF
BuildBot: translation: update po file automatically

[ci skip]
EOF

git push;

echo "Done.";
