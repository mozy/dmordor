module mordor.triton.py.manifest;

import tango.text.Util;
import tango.util.Convert;

import mordor.common.exception;
import mordor.common.streams.stream;
import mordor.common.stringutils;

class InvalidManifestException : PlatformException
{
    this(char[] msg)
    {
        super(msg);
    }
}

struct PatchInfo
{
    uint btime = -1;
    uint mtime = -1;
    uint ctime = -1;
    long filesize;
    long patchsize;
    int flags;
    ubyte[] hash;
    int attribs;
    
    static PatchInfo parse(string patchline)
    {
        PatchInfo pi;
        string[] fields = split(patchline, ":");
        switch (fields.length) {
            case 5:
                pi.btime = pi.mtime = to!(uint)(fields[0]);
                pi.filesize = to!(long)(fields[1]);
                pi.patchsize = to!(long)(fields[2]);
                pi.flags = to!(int)(fields[3]);
                pi.hash = cast(ubyte[])(fields[4]);
                break;
            case 6:
                pi.btime = to!(uint)(fields[0]);
                pi.mtime = to!(uint)(fields[1]);
                pi.filesize = to!(long)(fields[2]);
                pi.patchsize = to!(long)(fields[3]);
                pi.flags = to!(int)(fields[4]);
                pi.hash = cast(ubyte[])(fields[5]);
                break;
            case 8:
                pi.btime = to!(uint)(fields[0]);
                pi.mtime = to!(uint)(fields[1]);
                pi.ctime = to!(uint)(fields[2]);
                pi.filesize = to!(long)(fields[3]);
                pi.patchsize = to!(long)(fields[4]);
                pi.flags = to!(int)(fields[5]);
                pi.hash = cast(ubyte[])(fields[6]);
                pi.attribs = to!(int)(fields[7]);
                break;
            default:
                throw new InvalidManifestException("Invalid patchline " ~ patchline);                
        }
        return pi;
    }
}

void parseManifest(Stream stream,
                   void delegate(string) onFn = null,
                   void delegate(string) onPatchLine = null,
                   void delegate(PatchInfo) onPatchInfo = null,
                   void delegate(string, string) onUser = null)
in
{
    assert(stream.supportsRead);
}
body
{
    string line;
    while (true) {
        stream.getDelimited(line);
        if (line.length == 0)
            break;
        
        switch (line) {
            case "FILES":
                while (true) {
                    stream.getDelimited(line);
                    if (line.length == 0)
                        break;
                    string file = line;
                    if (onFn !is null)
                        onFn(file);
                    
                    bool foundChecksum = false;
                    while (true) {
                        stream.getDelimited(line);
                        if (line.length == 0) {
                            break;
                        }
                        if (foundChecksum) {
                            throw new InvalidManifestException("Unexpected patchline after checksum in file " ~ file);
                        }
                        if (line.length == 8) {
                            foundChecksum = true;
                            // TODO: verify checksum
                            continue;
                        }
                        if (onPatchLine !is null)
                            onPatchLine(line);
                        if (onPatchInfo !is null)
                            onPatchInfo(PatchInfo.parse(line));
                    }
                }
                break;
            case "USER":
                while (true) {
                    stream.getDelimited(line);
                    if (line.length == 0)
                        break;
                    // TODO: parse user line                    
                }
                break;
            default:
                throw new InvalidManifestException("Unknown manifest section " ~ line);
        }
    }
}

void parseManifest(Stream stream,
                   void delegate(string, PatchInfo[]) onStoredFile,
                   void delegate(string, string) onUser = null)
{
    string file;
    PatchInfo[] patches;

    parseManifest(stream,
        delegate void (string parsedFile) {
            if (file.length != 0) {
                onStoredFile(file, patches);
                patches.length = 0;
            }
            file = parsedFile;
        },
        null,
        delegate void(PatchInfo patch) {
            patches ~= patch;
        },
        onUser);
    if (file.length != 0) {
        onStoredFile(file, patches);
    }
}

void parseManifest(Stream stream,
                   void delegate(string, string[]) onStoredFile,
                   void delegate(string, string) onUser = null)
{
    string file;
    string[] patches;

    parseManifest(stream,
        delegate void (string parsedFile) {
            if (file.length != 0) {
                onStoredFile(file, patches);
                patches.length = 0;
            }
            file = parsedFile;
        },
        delegate void(string patch) {
            patches ~= patch;
        },
        null,
        onUser);
    if (file.length != 0) {
        onStoredFile(file, patches);
    }
}
