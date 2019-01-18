"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
/**
 * Flatten a 2-dimensional array into a 1-dimensional one.
 */
function flatten(xs) {
    return xs.reduce((a, b) => a.concat(b), []);
}
exports.flatten = flatten;
/**
 * Remove all duplicates from the list.
 * Doesn't preserve ordering.
 */
function uniq(a) {
    return Array.from(new Set(a));
}
exports.uniq = uniq;
/**
 * Removed all duplicates from the list based on the hash function.
 */
function uniqueBasedOnHash(list, elementToHash) {
    const hashSet = new Set();
    return list.reduce((accumulator, currentValue) => {
        const hash = elementToHash(currentValue);
        if (hashSet.has(hash)) {
            return accumulator;
        }
        hashSet.add(hash);
        return [...accumulator, currentValue];
    }, []);
}
exports.uniqueBasedOnHash = uniqueBasedOnHash;
//# sourceMappingURL=array.js.map