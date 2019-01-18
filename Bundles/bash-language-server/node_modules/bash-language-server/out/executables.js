"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const Fs = require("fs");
const Path = require("path");
const ArrayUtil = require("./util/array");
const FsUtil = require("./util/fs");
const ShUtil = require("./util/sh");
/**
 * Provides information based on the programs on your PATH
 */
class Executables {
    /**
     * @param path is expected to to be a ':' separated list of paths.
     */
    static fromPath(path) {
        const paths = path.split(':');
        const promises = paths.map(x => findExecutablesInPath(x));
        return Promise.all(promises)
            .then(ArrayUtil.flatten)
            .then(ArrayUtil.uniq)
            .then(executables => new Executables(executables));
    }
    constructor(executables) {
        this.executables = new Set(executables);
    }
    /**
     * Find all programs in your PATH
     */
    list() {
        return Array.from(this.executables.values());
    }
    /**
     * Check if the the given {{executable}} exists on the PATH
     */
    isExecutableOnPATH(executable) {
        return this.executables.has(executable);
    }
    /**
     * Look up documentation for the given executable.
     *
     * For now it simply tries to look up the MAN documentation.
     */
    documentation(executable) {
        return ShUtil.execShellScript(`man ${executable} | col -b`).then(doc => {
            return !doc
                ? Promise.resolve(`No MAN page for ${executable}`)
                : Promise.resolve(doc);
        });
    }
}
exports.default = Executables;
/**
 * Only returns direct children, or the path itself if it's an executable.
 */
function findExecutablesInPath(path) {
    return new Promise((resolve, _) => {
        Fs.lstat(path, (err, stat) => {
            if (err) {
                resolve([]);
            }
            else {
                if (stat.isDirectory()) {
                    Fs.readdir(path, (readDirErr, paths) => {
                        if (readDirErr) {
                            resolve([]);
                        }
                        else {
                            const files = paths.map(p => FsUtil.getStats(Path.join(path, p))
                                .then(s => (s.isFile() ? [Path.basename(p)] : []))
                                .catch(() => []));
                            resolve(Promise.all(files).then(ArrayUtil.flatten));
                        }
                    });
                }
                else if (stat.isFile()) {
                    resolve([Path.basename(path)]);
                }
                else {
                    // Something else.
                    resolve([]);
                }
            }
        });
    });
}
//# sourceMappingURL=executables.js.map