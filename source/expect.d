module expect;

import std.range : join, InputRange;
import std.string;

import context;

public class UnexpectedString : Exception
{

    this(ContextWindow context, string found, string expected)
    {
        super(context.format(found, "expected '" ~ expected ~ "' but '" ~ found ~ "' found instead"));
    }

    this(ContextWindow context, string found, string[] allowed)
    {
        string text = "expected '" ~ allowed.join('|') ~ "' but '" ~ found ~ "' found instead";
        super(context.format(found, text));
    }

}

bool isCommentOrEmpty(string line)
{
    return line.empty() || line.startsWith("#");
}

string raw(ContextWindow context, InputRange!string stream)
{
    if (stream.empty())
    {
        return null;
    }

    string s = stream.front();
    context.slideIn(s);

    return s.strip();
}

string peek(ContextWindow context, InputRange!string stream)
{
    string s = raw(context, stream);

    while (!(s is null) && isCommentOrEmpty(s))
    {
        stream.popFront();
        s = raw(context, stream);
    }

    return s;
}

string next(ContextWindow context, InputRange!string stream)
{
    if (!stream.empty())
    {
        stream.popFront();
    }

    return peek(context, stream);
}

string expectMatch(ContextWindow context, string s, InputRange!string stream)
{
    string found = peek(context, stream);

    if (s != found)
    {
        throw new UnexpectedString(context, s, found);
    }

    if (found != null)
    {
        stream.popFront();
    }

    return found;
}

string expectQuoted(ContextWindow context, string quoted)
{
    if (!quoted.startsWith("\""))
    {
        throw new UnexpectedString(context, quoted, "\"" ~ quoted);
    }
    quoted = quoted[1 .. $];
    if (!quoted.endsWith("\""))
    {
        throw new UnexpectedString(context, quoted, quoted ~ "\"");
    }
    return quoted[0 .. $ - 1];
}
