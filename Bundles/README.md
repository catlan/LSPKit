##  Setup

node from https://nodejs.org version 11.6.0 Current.

### bash-language-server

See [bash-language-server](https://github.com/mads-hartmann/bash-language-server)

mkdir tmp
cd tmp
npm install bash-language-server -prefix=.
cp -r node_modules PATH_TO_PROJECT/LSPKit/Bundles/bash-language-server/bash-language-server/

### vscode-html-languageserver

See [vscode-html-languageserver](https://github.com/Microsoft/vscode/tree/master/extensions/html-language-features/server) and [vscode-html-languageserver-bin](https://www.npmjs.com/package/vscode-html-languageserver-bin).

mkdir tmp
cd tmp
npm install vscode-html-languageserver-bin -prefix=.
cp -r node_modules PATH_TO_PROJECT/LSPKit/Bundles/vscode-html-languageserver/vscode-html-languageserver/
