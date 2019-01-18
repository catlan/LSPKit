"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const Fs = require("fs");
function getStats(path) {
    return new Promise((resolve, reject) => {
        Fs.lstat(path, (err, stat) => {
            if (err) {
                reject(err);
            }
            else {
                resolve(stat);
            }
        });
    });
}
exports.getStats = getStats;
//# sourceMappingURL=fs.js.map