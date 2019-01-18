# vscode-html-languageserver-bin

[![npm](https://img.shields.io/npm/v/vscode-html-languageserver-bin.svg)](https://www.npmjs.com/package/vscode-html-languageserver-bin)
[![Join the chat at https://gitter.im/vscode-langservers/Lobby](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/vscode-langservers/Lobby?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

Binary version published on npm of [vscode-html-languageserver](https://github.com/vscode-langservers/vscode-html-languageserver) extracted from [VSCode tree](https://github.com/Microsoft/vscode/tree/master/extensions/html/server)

# Features

-   [x] Completion provider
-   [x] Formatting
-   [x] Document Symbols & Highlights
-   [x] Document Links
-   [x] [CSS mode](https://github.com/vscode-langservers/vscode-css-languageserver-bin#features)
-   [x] Javascript mode

# Clients

-   [Oni](https://github.com/onivim/oni)
-   [ide-html](https://github.com/liuderchi/ide-html)

## Getting Started

These instructions will get you a copy of the project up and running on your local machine for development and testing purposes. See deployment for notes on how to deploy the project on a live system.

### Prerequisites

To install this Language Server you need [npm](https://www.npmjs.com/get-npm) on your machine

### Installing

```bash
npm install --global vscode-html-languageserver-bin
```

### Launching the Server

The common way to launch it is by using stdio transport:

```bash
html-languageserver --stdio
```

The server can also be launched with one of the following transports:

```bash
html-languageserver --socket={number}
html-languageserver --node-ipc
```

## Deployment

```bash
npm run publish
# or to try locally
npm run pack
```

## Contributing

PRs are welcome.
To setup the repo locally run:
```bash
git clone --recursive https://github.com/vscode-langservers/vscode-html-languageserver-bin
cd vscode-html-languageserver-bin
npm install
npm run pack
```

## Versioning

We use [SemVer](http://semver.org/) for versioning.

Because we [can't guess](https://github.com/vscode-langservers/vscode-html-languageserver/blob/master/package.json#L4) VSCode extention version, we update `MINOR` when submodule is updated and `PATCH` when only build method is updated

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details
This is a derived work please see [VSCode's LICENSE.txt](https://github.com/Microsoft/vscode/blob/master/LICENSE.txt) for the original copyright and license.

