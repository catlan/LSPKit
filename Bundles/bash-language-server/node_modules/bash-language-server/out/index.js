'use strict';
Object.defineProperty(exports, "__esModule", { value: true });
const LSP = require("vscode-languageserver");
const server_1 = require("./server");
// tslint:disable-next-line:no-var-requires
const pkg = require('../package');
function listen() {
    // Create a connection for the server.
    // The connection uses stdin/stdout for communication.
    const connection = LSP.createConnection(new LSP.StreamMessageReader(process.stdin), new LSP.StreamMessageWriter(process.stdout));
    connection.onInitialize((params) => {
        connection.console.log(`Initialized server v. ${pkg.version} for ${params.rootUri}`);
        return server_1.default.initialize(connection, params)
            .then(server => {
            server.register(connection);
            return server;
        })
            .then(server => ({
            capabilities: server.capabilities(),
        }));
    });
    connection.listen();
}
exports.listen = listen;
//# sourceMappingURL=index.js.map