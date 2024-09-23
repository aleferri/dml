module context;

import std.string;
import std.range;
import std.conv;

class ContextWindow
{

    private string[4] lines;
    private ubyte cursor;
    private ulong lineNumber;

    this()
    {
        this.cursor = 0;
        this.lineNumber = 0;
    }

    public void slideIn(string line)
    {
        this.lineNumber++;
        this.lines[cursor] = line;
        this.cursor = (this.cursor + 1) % this.lines.length;
    }

    public string format(string token, string error)
    {
        string message = "Error at line " ~ this.lineNumber.to!string ~ ":";
        string lastLine = "";
        ubyte index = this.cursor;

        for (uint i = 0; i < this.lines.length; i++)
        {
            if (this.lines[index] != null)
            {
                lastLine = this.lines[index];
                message ~= this.lines[index] ~ "\n";
            }

            index = (index + 1) % this.lines.length;
        }

        ulong startOf = lastLine.indexOf(token);
        message ~= "_".repeat(startOf).join("") ~ "^".repeat(token.length).join("") ~ "\n";
        message ~= error;

        return message;
    }

    public string window()
    {
        string message = "";
        ubyte index = this.cursor;

        for (uint i = 0; i < this.lines.length; i++)
        {
            if (this.lines[index] != null)
            {
                message ~= this.lines[index] ~ "\n";
            }

            index = (index + 1) % this.lines.length;
        }

        return message;
    }

}
