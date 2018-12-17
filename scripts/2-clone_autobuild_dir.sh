git config --global user.name "CircleCI";
git config --global user.email "CircleCI";

ssh -o StrictHostKeyChecking=no git@github.com

git clone  --depth=1 git@github.com:Ansuel/gui-dev-build-auto.git $HOME/gui-dev-build-auto/

if [ ! -d $HOME/gui-dev-build-auto/modular ]; then
	mkdir $HOME/gui-dev-build-auto/modular
fi
	