"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
function getExplainshellEndpoint() {
    const { EXPLAINSHELL_ENDPOINT } = process.env;
    return typeof EXPLAINSHELL_ENDPOINT !== 'undefined' ? EXPLAINSHELL_ENDPOINT : null;
}
exports.getExplainshellEndpoint = getExplainshellEndpoint;
function getHighlightParsingError() {
    const { HIGHLIGHT_PARSING_ERRORS } = process.env;
    return typeof HIGHLIGHT_PARSING_ERRORS !== 'undefined'
        ? HIGHLIGHT_PARSING_ERRORS === 'true'
        : true;
}
exports.getHighlightParsingError = getHighlightParsingError;
//# sourceMappingURL=config.js.map