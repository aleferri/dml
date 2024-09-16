module pofile;

import std.range;
import std.string;
import std.conv;
import std.algorithm;
import std.array;

private struct POHeader
{
    string projectId;
    string reportTo;
    string revisionDate;
    string lastTranslator;
    string languageTeam;
    string language;
    string mime;
    string contentType;
    string contentTransferEncoding;
    ulong pluralsForms;
    string pluralExpression;
}

private struct POEntry
{
    string msgId;
    string msgIdPlural;
    string msgContext;
    string msgTemplate;
    string[] msgTemplatePlurals;
}

public class MissingHeader : Exception
{

    this(string msg)
    {
        super(msg);
    }

}

public class UnexpectedString : Exception
{

    this(string found, string expected)
    {
        super("expected '" ~ expected ~ "' but '" ~ found ~ "' found instead");
    }

}

string skipCommentsOrEmpty(InputRange!string stream)
{
    if (stream.empty())
    {
        return null;
    }

    string s = stream.front();
    while (1)
    {
        s = s.strip();
        if (!s.startsWith("#") && !s.empty())
        {
            stream.popFront();
            return s;
        }

        if (stream.empty())
        {
            break;
        }
        stream.popFront();
        s = stream.front();
    }

    return null;
}

string expectMatch(string s, InputRange!string stream)
{
    string found = skipCommentsOrEmpty(stream);

    if (s != found)
    {
        throw new UnexpectedString(s, found);
    }

    return found;
}

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

    foreach (string expr; lines) {
        expr = expr.strip();
        if (!expr.empty()) {
            if (expr.startsWith("nplurals=")) {
                header.pluralsForms = expr.replace("nplurals=", "").to!long();
            } else if (expr.startsWith("plural=")) {
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

POHeader readHeader(InputRange!string stream)
{
    POHeader header = POHeader();

    expectMatch("msgid \"\"", stream);
    expectMatch("msgstr \"\"", stream);

    string line = skipCommentsOrEmpty(stream);
    while (line != null && line.startsWith("\""))
    {
        // this starts as an header
        if (!line.endsWith("\\n\""))
        {
            throw new UnexpectedString("line end", "\\n\"");
        }

        string payload = line[1 .. $-3];

        // this is an header, check which one

        long colonOffset = payload.indexOf(":");

        if (colonOffset < 0)
        {
            throw new UnexpectedString("line end", ":");
        }

        string headerName = payload[0 .. colonOffset];

        if (headerName in headersParsersByName)
        {
            auto parser = headersParsersByName[headerName];

            if (parser != null)
            {
                parser(payload, headerName, header);
            }
        }

        line = skipCommentsOrEmpty(stream);
    }

    return header;
}

unittest
{
    import std.stdio;
    import std.file;

    auto stream = new File("testdata/simplepo.po").byLine().map!(a => a.to!string);
    writeln(readHeader(inputRangeObject(stream)));
}
