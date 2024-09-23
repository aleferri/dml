module pofile;

import std.string;

import expression;

struct POHeader
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

struct POEntry
{
    string id;
    string pluralId;
    string context;
    string[] messages;
}

class POFile
{

    private immutable POHeader header;
    private const POEntry[] entries;

    this(POHeader header, POEntry[] entries)
    {
        this.header = header;
        this.entries = entries.dup;
    }

    public string lookup(string id)
    {
        foreach (entry; this.entries)
        {
            if (entry.id == id)
            {
                return entry.messages[0];
            }
        }

        return null;
    }

    public string lookup(string id, int n)
    {
        foreach (entry; this.entries)
        {
            if (entry.id == id)
            {
                const i = this.eval(n);
                return entry.messages[i];
            }
        }

        return null;
    }

    private ulong eval(int n)
    {
        string e = this.header.pluralExpression;

        auto index = compileExpression!int(e);
        index.n = n;

        return index();
    }

}
