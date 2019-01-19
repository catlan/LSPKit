##  Setup

Node.js from https://nodejs.org version 10.15.0.
```shell
sudo npm install -g pkg
```

### bash-language-server

See [bash-language-server](https://github.com/mads-hartmann/bash-language-server)
```shell
mkdir tmp
cd tmp
npm install -prefix=. bash-language-server
pkg -t node10-macos-x64 -o bash-language-server ./node_modules/bash-language-server/bin/main.js
cp node_modules/**/*.node ./
```
### vscode-html-languageserver

See [vscode-html-languageserver](https://github.com/Microsoft/vscode/tree/master/extensions/html-language-features/server) and [vscode-html-languageserver-bin](https://www.npmjs.com/package/vscode-html-languageserver-bin).
```shell
mkdir tmp
cd tmp
npm install -prefix=. vscode-html-languageserver-bin
pkg -t node10-macos-x64 -o vscode-html-languageserver ./node_modules/vscode-html-languageserver-bin/htmlServerMain.js
```

