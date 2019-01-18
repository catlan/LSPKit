"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const ChildProcess = require("child_process");
/**
 * Execute the following sh program.
 */
function execShellScript(body) {
    const args = ['-c', body];
    const process = ChildProcess.spawn('bash', args);
    return new Promise((resolve, reject) => {
        let output = '';
        process.stdout.on('data', buffer => {
            output += buffer;
        });
        process.on('close', returnCode => {
            if (returnCode === 0) {
                resolve(output);
            }
            else {
                reject(`Failed to execute ${body}`);
            }
        });
    });
}
exports.execShellScript = execShellScript;
//# sourceMappingURL=sh.js.map