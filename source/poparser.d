module poparser;

import std.range;
import std.string;
import std.conv;
import std.algorithm;
import std.array;
import std.ascii;

import expect;
import context;
import pofile;

string extractHeaderValue(string line, string name)
{
    const offset = name.length + 1;

    return line[offset .. $].strip();
}

void parseProjectId(string line, string name, ref POHeader header)
{
    header.projectId = extractHeaderValue(line, name);
}

void parseReportTo(string line, string name, ref POHeader header)
{
    header.reportTo = extractHeaderValue(line, name);
}

void parseLastRevision(string line, string name, ref POHeader header)
{
    header.revisionDate = extractHeaderValue(line, name);
}

void parseLastTranslator(string line, string name, ref POHeader header)
{
    header.lastTranslator = extractHeaderValue(line, name);
}

void parseLanguage(string line, string name, ref POHeader header)
{
    header.language = extractHeaderValue(line, name);
}

void parseMime(string line, string name, ref POHeader header)
{
    header.mime = extractHeaderValue(line, name);
}

void parseContentType(string line, string name, ref POHeader header)
{
    header.contentType = extractHeaderValue(line, name);
}

void parseContentEncoding(string line, string name, ref POHeader header)
{
    header.contentTransferEncoding = extractHeaderValue(line, name);
}

void parsePluralForms(string line, string name, ref POHeader header)
{
    string statement = extractHeaderValue(line, name);

    string[] lines = statement.split(';');

    foreach (string expr; lines)
    {
        expr = expr.strip();
        if (!expr.empty())
        {
            if (expr.startsWith("nplurals="))
            {
                header.pluralsForms = expr.replace("nplurals=", "").to!long();
            }
            else if (expr.startsWith("plural="))
            {
                header.pluralExpression = expr.replace("plural=", "");
            }
        }
    }
}

private alias headerParser = void function(string line, string name, ref POHeader header);

private static headerParser[string] headersParsersByName;

private static this()
{
    headersParsersByName = [
        "Project-Id-Version": &parseProjectId,
        "Report-Msgid-Bugs-To": &parseReportTo,
        "Revision-Date": &parseLastRevision,
        "Last-Translator": &parseLastTranslator,
        "Language": &parseLanguage,
        "MIME-Version": &parseMime,
        "Content-Type": &parseContentType,
        "Content-Transfer-Encoding": &parseContentEncoding,
        "Plural-Forms": &parsePluralForms
    ];
}

POHeader parseHeader(ContextWindow context, InputRange!string stream)
{
    POHeader header = POHeader();

    expectMatch(context, "msgid \"\"", stream);
    expectMatch(context, "msgstr \"\"", stream);

    string line = peek(context, stream);
    while (line != null && line.startsWith("\""))
    {
        // this starts as an header
        if (!line.endsWith("\\n\""))
        {
            throw new UnexpectedString(context, "line end", "\\n\"");
        }

        string payload = line[1 .. $ - 3];

        // this is an header, check which one

        long colonOffset = payload.indexOf(":");

        if (colonOffset < 0)
        {
            throw new UnexpectedString(context, "line end", ":");
        }

        string headerName = payload[0 .. colonOffset];

        if (headerName in headersParsersByName)
        {
            auto parser = headersParsersByName[headerName];

            parser(payload, headerName, header);
        }

        line = next(context, stream);
    }

    return header;
}

POEntry[] parseBody(ContextWindow context, InputRange!string stream)
{
    POEntry[] entries = [];

    string line = peek(context, stream);
    bool validRecord = false;
    bool hasPlural = false;
    POEntry entry = POEntry();

    while (line != null)
    {
        if (!line.empty())
        {
            if (line.startsWith("msgid "))
            {
                if (validRecord)
                {
                    if (entry.messages.length > 0)
                    {
                        entries ~= entry;
                    }
                    else
                    {
                        throw new UnexpectedString(context, "msgstr", "msgid");
                    }
                    entry = POEntry();
                }

                entry.id = expectQuoted(context, line.replace("msgid", "").strip());
                validRecord = true;
                hasPlural = false;
            }
            else if (line.startsWith("msgid_plural "))
            {
                if (!validRecord)
                {
                    throw new UnexpectedString(context, "msgid", "msgid_plural");
                }
                entry.pluralId = expectQuoted(context, line.replace("msgid_plural", "").strip());
                hasPlural = true;
            }
            else if (line.startsWith("msgstr "))
            {
                if (!validRecord)
                {
                    throw new UnexpectedString(context, "msgid", "msgstr");
                }

                entry.messages ~= expectQuoted(context, line.replace("msgstr", "").strip());
            }
            else if (line.startsWith("msgstr["))
            {
                string prefix = "msgstr[";

                string token = line[0 .. prefix.length + 2];
                char n = token[$ - 2];

                if (!isDigit(n))
                {
                    throw new UnexpectedString(context, "msgstr[number]", token);
                }

                if (!validRecord)
                {
                    throw new UnexpectedString(context, "msgid", token);
                }

                if (!hasPlural)
                {
                    throw new UnexpectedString(context, "msgid", token);
                }

                uint index = (n - '0');

                while (entry.messages.length < index + 1)
                {
                    entry.messages ~= "";
                }

                entry.messages[index] = expectQuoted(context, line.replace(token, "").strip());
            }
        }

        line = next(context, stream);
    }

    if (validRecord)
    {
        entries ~= entry;
    }

    return entries;
}

unittest
{
    import std.stdio;
    import std.file;

    auto context = new ContextWindow();
    auto stream = new File("testdata/simplepo.po").byLine().map!(a => a.to!string);
    auto input = inputRangeObject(stream);
    POHeader header = parseHeader(context, input);
    writeln(header);
    writeln(parseBody(context, input));
}
