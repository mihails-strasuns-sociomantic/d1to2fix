/******************************************************************************

    Defines exact mappings between D1 and D2 code and does final file output.

    Copyright: Copyright (c) 2016 Sociomantic Labs. All rights reserved

    License: Boost Software License Version 1.0 (see LICENSE for details)

******************************************************************************/

module d1to2fix.converter;

import d1to2fix.visitor;
import dparse.lexer;
import std.algorithm.searching : canFind;

/**

    Prepares data for conversion

    Doesn't actual conversion on its own but instead returns a struct instance
    with a single `writeTo` method. This is done simply to prettify the API.

    Params:
        tokens = array of tokens from initial lexing (with comments and
            whitespaces)
        token_mappings = aggregate with all mappings between AST and token
            array that will be needed for conversion

    Returns:
        converter struct

 **/
public Converter convert ( const(Token)[] tokens,
    TokenMappings token_mappings )
{
    return Converter(tokens, token_mappings);
}

/**
 * List of tokens that can be injected through `d1to2fix_inject`
 */
private static immutable allowed_tokens = [ "const", "inout", "scope" ];

private struct Converter
{
    import std.stdio : File;

    private const(Token)[] tokens;
    private TokenMappings token_mappings;

    void writeTo ( File output )
    in
    {
        assert (this.tokens.length > 0);
    }
    body
    {
        void writeToken ( in Token token )
        {
            // Tokens for special symbols used in language don't have any
            // text value and require extra step to get back to text form
            output.write(token.text is null ? str(token.type) : token.text);
        }

        foreach (index, token; this.tokens)
        {
            scope (exit)
            {
                // Getting rid of mappings for already processed tokens to
                // speed up further lookups
                this.token_mappings.test_blocks.removeUntil(token.index);
            }

            switch (token.type)
            {
                case tok!"assert":
                    if (this.token_mappings.test_blocks.contain(token.index))
                        output.write("test");
                    else
                        output.write("assert");
                    break;
                default:
                    writeToken(token);
                    break;
            }
        }
    }
}
