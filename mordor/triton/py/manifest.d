module mordor.triton.py.manifest;

import tango.text.Util;
import tango.util.Convert;

import mordor.common.exception;
import mordor.common.sqlite;
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
    int btime = -1;
    int mtime = -1;
    int ctime = -1;
    long filesize;
    long patchsize;
    int flags;
    ubyte[] hash;
    int attribs;    
    
    static PatchInfo parse(string patchline)
    {
        PatchInfo pi;
        string hashstring;
        string[] fields = split(patchline, ":");
        switch (fields.length) {
            case 5:
                pi.btime = pi.mtime = to!(int)(fields[0]);
                pi.filesize = to!(long)(fields[1]);
                pi.flags = to!(int)(fields[2]);
                hashstring = fields[3];
                pi.patchsize = to!(long)(fields[4]);
                break;
            case 6:
                pi.btime = to!(int)(fields[0]);
                pi.mtime = to!(int)(fields[1]);
                pi.filesize = to!(long)(fields[2]);
                pi.flags = to!(int)(fields[3]);
                hashstring = fields[4];
                pi.patchsize = to!(long)(fields[5]);
                break;
            case 8:
                pi.btime = to!(int)(fields[0]);
                pi.mtime = to!(int)(fields[1]);
                pi.ctime = to!(int)(fields[2]);
                pi.filesize = to!(long)(fields[3]);
                pi.flags = to!(int)(fields[4]);
                hashstring = fields[5];
                pi.attribs = to!(int)(fields[6]);
                pi.patchsize = to!(long)(fields[7]);
                break;
            default:
                throw new ConversionException("Invalid patchline " ~ patchline);                
        }
        if (hashstring.length != 40 || !isHexString(hashstring))
            throw new ConversionException("Invalid hash " ~ hashstring);
        pi.hash = hexstringToData(hashstring);
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
        try {
            stream.getDelimited(line);
            if (line.length == 0)
                break;
        } catch (UnexpectedEofException) {
            break;
        }
        
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

class SqliteManifest
{
    this(string file)
    {
        _db = new Database(file);
    }
    
    void parse(Stream stream)
    {
        _db.begin();
        scope (failure) _db.rollback();
        scope (success) _db.commit();

        scope insertFile = _db.prepare("INSERT INTO files (path) VALUES (?)");
        scope insertPatch = _db.prepare("INSERT INTO patches (file_id, btime, mtime, ctime, filesize, patchsize, flags, hash, attribs) "
            "VALUES (?, ?, ?, ?, ?, ? , ?, ?, ?)");
        scope insertUser = _db.prepare("INSERT INTO user (key, value) VALUES (?, ?)");
        
        parseManifest(stream,
            delegate void(string filename) {
                insertFile[1] = filename;
                insertFile.executeUpdate();
                insertPatch[1] = _db.lastInsertRowId;
            },
            null,
            delegate void(PatchInfo patchinfo) {
                insertPatch[2] = patchinfo.btime;
                insertPatch[3] = patchinfo.mtime;
                insertPatch[4] = patchinfo.ctime;
                insertPatch[5] = patchinfo.filesize;
                insertPatch[6] = patchinfo.patchsize;
                insertPatch[7] = patchinfo.flags;
                insertPatch[8] = patchinfo.hash;
                insertPatch[9] = patchinfo.attribs;
                insertPatch.executeUpdate();
            },
            delegate void(string key, string value) {
                insertUser[1] = key;
                insertUser[2] = value;
                insertUser.executeUpdate();
            });
    }

private:
    Database _db;
}

import mordor.common.streams.buffered;
import mordor.common.streams.file;
import mordor.common.streams.std;

void main(string[] args)
{
    if (args.length == 2) {
        scope manifest = new SqliteManifest(args[1]);
        manifest.parse(new BufferedStream(new StdinStream()));
    } else if (args.length == 3) {
        scope manifest = new SqliteManifest(args[2]);
        manifest.parse(new BufferedStream(new FileStream(args[1], FileStream.Flags.READ)));
    }
}
