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
                pi.patchsize = to!(long)(fields[6]);
                pi.attribs = to!(int)(fields[7]);
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
import tango.io.Stdout;
class SqliteManifest
{
    this(string file, char slash = '/')
    {
        _slash = slash;
        _db = new Database(file);
        _db.createFunction("HasAdditionalSlash", 2,
            delegate void (Result result, Value[] args)
            in
            {
                assert(args.length == 2);
            }
            body
            {
                string str = args[1].get!(string)();
                if (str.length == 0) {
                    result = 0;
                    return;
                } else {
                    size_t ret = locate(str, _slash, args[0].get!(int)());
                    if (ret == str.length) {
                        result = 0;
                        return;
                    } else {
                        result = ret;
                        return;
                    }
                }
            });
        _db.createFunction("Child", 2,
            delegate void (Result result, Value[] args)
            in
            {
                assert(args.length == 2);
            }
            body
            {
                string str = args[0].get!(string)();
                size_t len = args[1].get!(size_t)();
                size_t slash = locate(str, _slash, len);
                Stdout.formatln("str '{}' length {} slash {} str.length {}", str, len, slash, str.length);
                result = str[len..slash];
            });
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
import tango.io.Stdout;
    PatchInfo[] find(string file)
    {
        if (_findFile is null) {
            _findFile = _db.prepare("SELECT btime, mtime, ctime, filesize, patchsize, flags, hash, attribs "
                "FROM patches INNER JOIN files ON files.id=file_id WHERE path=? ORDER BY btime");
        }
        synchronized (_findFile) {
            Stdout.formatln("prepared");
            _findFile[1] = file;
            PatchInfo[] result;
            auto results = _findFile.execute();
            Stdout.formatln("executed");
            while (results.next()) {
                Stdout.formatln("got patch");
                result ~= PatchInfo(
                    results.opIndex!(int)(0),
                    results.opIndex!(int)(1),
                    results.opIndex!(int)(2),
                    results.opIndex!(long)(3),
                    results.opIndex!(long)(4),
                    results.opIndex!(int)(5),
                    cast(ubyte[])results.opIndex!(void[])(6),
                    results.opIndex!(int)(7)
                    );
            }
            Stdout.formatln("complete");
            return result;
        }
    }

    bool dirExists(string path)
    {
        if (_dirExists is null) {
            _dirExists = _db.prepare("SELECT NULL FROM files WHERE path>=? AND path<? LIMIT 1");
        }
        string path2;
        if (path.length == 0)
            return true;
        if (path[$-1] != _slash)
            path ~= _slash;
        path2 = path.dup;
        ++path2[$-1];
        synchronized (_dirExists) {
            Stdout.formatln("'{}', '{}'", path, path2);
            _dirExists[1] = path;
            _dirExists[2] = path2;
            auto results = _dirExists.execute();
            scope (exit) delete results;
            if (results.next()) {
                Stdout.formatln("exists");
                return true;
            } else {
                Stdout.formatln("doesn't exist");
                return false;
            }
        }
    }
    
    private class ChildrenClosure
    {
        string path;
        int run(int delegate(ref string) dg)
        {
            int ret;
            auto stmt = _db.prepare("SELECT * FROM files WHERE path >= ?1 AND path < ?2");
            scope (exit) delete stmt;
            string path2;
            if (path.length == 0 && _slash == '\\') {
                path2 ~= 'Z' + 1;
            } else {
                if (path.length == 0)
                    path ~= _slash;
                else if (path[$-1] != _slash)
                    path ~= _slash;
                path2 = path.dup;
                ++path2[$-1];
            }
            stmt[1] = path;
            stmt[2] = path2;
            //stmt[3] = path.length;
            Stdout.formatln("'{}', '{}', {}", path, path2, path.length);
            auto results = stmt.execute();
            scope (exit) delete results;
            while (results.next()) {
                string p = results.opIndex!(string)(0);
                if ((ret = dg(p)) != 0) return ret;
            }
            return 0;
        }
    }
    
    int delegate(int delegate(ref string)) children(string path)
    {
        auto closure = new ChildrenClosure();
        closure.path = path.dup;
        return &closure.run;        
    }

private:
    Database _db;
    PreparedStatement _findFile, _dirExists;
    char _slash;
}

debug(parsemanifest) {
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
}
