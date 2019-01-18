"use strict";
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : new P(function (resolve) { resolve(result.value); }).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
Object.defineProperty(exports, "__esModule", { value: true });
const ShUtil = require("./util/sh");
// You can generate this list by running `compgen -b` in a bash session
exports.LIST = [
    '.',
    ':',
    '[',
    'alias',
    'bg',
    'bind',
    'break',
    'builtin',
    'caller',
    'cd',
    'command',
    'compgen',
    'complete',
    'continue',
    'declare',
    'dirs',
    'disown',
    'echo',
    'enable',
    'eval',
    'exec',
    'exit',
    'export',
    'false',
    'fc',
    'fg',
    'getopts',
    'hash',
    'help',
    'history',
    'jobs',
    'kill',
    'let',
    'local',
    'logout',
    'popd',
    'printf',
    'pushd',
    'pwd',
    'read',
    'readonly',
    'return',
    'set',
    'shift',
    'shopt',
    'source',
    'suspend',
    'test',
    'times',
    'trap',
    'true',
    'type',
    'typeset',
    'ulimit',
    'umask',
    'unalias',
    'unset',
    'wait',
];
function isBuiltin(word) {
    return exports.LIST.find(builtin => builtin === word) !== undefined;
}
exports.isBuiltin = isBuiltin;
function documentation(builtin) {
    return __awaiter(this, void 0, void 0, function* () {
        const errorMessage = `No help page for ${builtin}`;
        try {
            const doc = yield ShUtil.execShellScript(`help ${builtin}`);
            return doc || errorMessage;
        }
        catch (error) {
            return errorMessage;
        }
    });
}
exports.documentation = documentation;
//# sourceMappingURL=builtins.js.map