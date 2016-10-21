/******************************************************************************

    Module built on top of dsymbol library facilities which provides means
    to find D symbols and reasons about them.

    Copyright: Copyright (c) 2016 Sociomantic Labs. All rights reserved

    License: Boost Software License Version 1.0 (see LICENSE for details)

******************************************************************************/

module d1to2fix.symbolsearch;

import dsymbol.modulecache;
import dsymbol.symbol;

/**
    Initializes module cache and all derived facilities by parsing all
    modules that can be found under specified import paths.

    NB: must be called in main thread before any file conversion workers
    start to avoid any race conditions

    Params:
        paths = array of import paths to scan
 **/

public void initializeModuleCache(string[] paths)
{
    import std.exception;
    enforce(delegate_cache is null);

    // static is used so that pointer persists and GC won't collect it
    // together with underlying owned dsymbols
    static ModuleCache* module_cache;
    module_cache = new ModuleCache(new ASTAllocator);
    module_cache.addImportPaths(paths);

    const(DSymbol)*[string] delegates;

    void collectNames (const(DSymbol*)[] symbols)
    {
        foreach (symbol; symbols)
        {
            // dsymbol tracks both delegates and lambdas as "function" thus
            // next condition may result in false positives but it is ok
            // as dmd will compile scope lambda declaration just fine

            if (   symbol.kind == CompletionKind.aliasName
                && symbol.type !is null
                && symbol.type.name == "function")
            {
                delegates[symbol.name] = symbol;
            }

            // Recursing into aggregates causes stack overflow, probably
            // a smarter iteration algorithm is needed to do it. Ignoring
            // them for now and only checking modules/packages:

            if (   symbol.kind == CompletionKind.moduleName
                || symbol.kind == CompletionKind.packageName
                || symbol.kind == CompletionKind.structName
                || symbol.kind == CompletionKind.interfaceName
                || symbol.kind == CompletionKind.className)
            {
                collectNames((*symbol)[]);
            }
        }
    }

    import std.array;
    import std.algorithm;
    collectNames(module_cache.getAllSymbols().map!(entry => entry.symbol).array());

    delegate_cache = new shared DelegateCache(cast(immutable) delegates);
}

/**
    Tries to find alias declaration with given (unqualified) name that
    resolves to delegate type.

    As name is unqualified false positives may happen thus delegate alias names
    must not clash with names of other types.

    Params:
        symbolName = symbol name to lookup

    Returns:
        pointer to matching D symbol if there is a delegate alias with such
        name in scanned code base
 **/

public const(DSymbol)* delegateAliasSearch(string symbolName)
{
    return delegate_cache.search(symbolName);
}

/**
    Wraps name to DSymbol associative array so that it can be allocated
    on heap as shared entity.
 **/

private struct DelegateCache
{
    immutable DSymbol*[string] cache;

    const(DSymbol)* search(string symbolName) immutable
    {
        if (auto sym = symbolName in this.cache)
            return *sym;
        else
            return null;
    }
}

/**
    Immutable/shared cache of found delegate type aliases

 **/

private shared immutable(DelegateCache)* delegate_cache;
