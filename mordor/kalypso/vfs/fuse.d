module mordor.kalypso.vfs.fuse;

import tango.core.Memory;
import tango.core.Thread;
import tango.stdc.errno;
import tango.stdc.stdint;
import tango.stdc.stringz;
import tango.stdc.posix.fcntl;
import tango.stdc.posix.sys.stat;
import tango.text.util;
import tango.util.log.AppendConsole;
import tango.util.log.Log;

import fuse.fuse;

import mordor.common.config;
import mordor.common.iomanager;
import mordor.common.log;
import mordor.kalypso.vfs.helpers;
import mordor.kalypso.vfs.model;
import mordor.kalypso.vfs.triton;

IObject _root;
Logger _log, _logReaddir;
extern (C) int printf(char* format, ...);
static this()
{
    _log = Log.lookup("mordor.kalypso.vfs.fuse");
    _logReaddir = Log.lookup("mordor.kalypso.vfs.fuse.readdir");
}

void attachThread()
{
    bool needWorker = false;
    if (Thread.getThis is null) {
        thread_attachThis();
        needWorker = true;
    }
    thread_reattachThis();
    if (needWorker) {
        new WorkerPool("fuse", 1, true);
    }
}
    
extern (C) int vfs_getattr(char* path, stat_t* stbuf)
{
    attachThread();
    _log.trace("in getattr");
    try {
        char[] pathstr = fromStringz(path);
        _log.trace("getattr '{}'", pathstr);
        switch (pathstr) {
            case "/":
                stbuf.st_mode = S_IFDIR | 0755;
                stbuf.st_nlink = 3;
                return 0;
            case "/._.":
            case "/.metadata_never_index":
            case "/Backups.backupdb":
            case "/mach_kernel":
            case "/.DS_Store":
            case "/.Spotlight-V100":
            case "/DCIM":
                return -ENOENT;
            default:
                break;
        }
        auto obj = _root.find(pathstr);
        if (obj is null)
            return -ENOENT;
        switch(obj["type"].get!(string)) {
            case "directory":
                stbuf.st_mode = S_IFDIR | 0755;
                stbuf.st_nlink = 3;
                return 0;
            default:
                return -EIO;        
        }
    } catch (Object o) {
        auto ex = cast(Exception)o;
        if (ex !is null) {
            _log.fatal("In getattr, unhandled exception: {}@{}:{}", ex, ex.file, ex.line);
            if (ex.next !is null) {
                ex = ex.next;
                _log.fatal("In getattr, unhandled exception: {}@{}:{}", ex, ex.file, ex.line);
            }
        } else {
            _log.fatal("In getattr, unhandled exception: {}", o);
        }
        return -EIO;
    }
}

struct DirContext
{
    off_t offset;
    bool done;
    bool full;
    Fiber fiber;
    void* buf;
    fuse_fill_dir_t filler;
    IObject obj;
    
    void run()
    {
        if (done) {
            _logReaddir.trace("readdir aborted");
            return;
        }
        ++offset;
        _logReaddir.trace("readdir worker '.' ({})", offset);
        if (filler(buf, ".\0", null, offset)) {
            _logReaddir.trace("readdir buffer full");
            full = true;
            Fiber.yield();
            if (done) {
                _logReaddir.trace("readdir aborted");
                return;
            }
        }
        ++offset;
        _logReaddir.trace("readdir worker '..' ({})", offset);
        if (filler(buf, "..\0", null, offset)) {
            _logReaddir.trace("readdir buffer full");
            full = true;
            Fiber.yield();
            if (done) {
                _logReaddir.trace("readdir aborted");
                return;
            }
        }
        stat_t stbuf;
        stat_t* stptr;
        foreach(c; &obj.children) {
            string path = c["name"].get!(string);
            string type = c["type"].get!(string);
            switch (type) {
                case "directory":
                    stbuf.st_mode = S_IFDIR | 0755;
                    stbuf.st_nlink = 3;
                    stptr = &stbuf;
                    break;
                default:
                    stptr = null;
                    break;
            }
            ++offset;
            _logReaddir.trace("readdir worker '{}' is a {} ({})", path, type, offset);
            if (filler(buf, toStringz(path), stptr, offset)) {
                _logReaddir.trace("readdir buffer full");
                full = true;
                Fiber.yield();
                if (done) {
                    _logReaddir.trace("readdir aborted");
                    return;
                }
            }
        }
        _logReaddir.trace("readdir complete");
    }
}

extern (C) int vfs_opendir(char* path, fuse_file_info* fi)
{
    attachThread();
    try {
        char[] pathstr = fromStringz(path);
        _log.trace("opendir '{}'", pathstr);
        IObject obj = _root.find(pathstr[1..$]);
        if (obj is null)
            return -ENOENT;
        auto ctx = new DirContext();
        ctx.obj = obj;
        ctx.fiber = new Fiber(&ctx.run, 128 * 1024);
        GC.addRoot(ctx);
        fi.fh = cast(uint64_t)ctx;
        return 0;
    } catch (Object o) {
        return -ENOENT;
    }
}

extern (C) int vfs_readdir(char *path, void *buf, fuse_fill_dir_t filler,
              off_t offset, fuse_file_info *fi)
{
    attachThread();
    try {
        auto ctx = cast(DirContext*)fi.fh;
        assert(ctx);
        _log.trace("readdir '{}' ({})", getPathRelativeTo(ctx.obj, _root, true), offset);
        
        if (offset != ctx.offset) {
            return -ENOENT;
        }
        
        ctx.buf = buf;
        ctx.filler = filler;
        ctx.full = false;
        
        while (true) {
            if (ctx.full || ctx.fiber.state == Fiber.State.TERM)
                return 0;
            ctx.fiber.call();
        }
    } catch (Object o) {
        _log.error("oh crap {}", o);
        return 0;
    }
}

extern (C) int vfs_releasedir(char* path, fuse_file_info* fi)
{
    attachThread();
    auto ctx = cast(DirContext*)fi.fh;
    assert(ctx);
    _log.trace("releasedir '{}'", getPathRelativeTo(ctx.obj, _root, true));
    ctx.done = true;
    if (ctx.fiber.state != Fiber.State.TERM)
        ctx.fiber.call();
    assert(ctx.fiber.state == Fiber.State.TERM);
    GC.removeRoot(ctx);
    delete ctx.fiber;
    delete ctx;
    return 0;
}


fuse_operations ops = {
    getattr : &vfs_getattr,
    opendir : &vfs_opendir,
    readdir : &vfs_readdir,
    releasedir : &vfs_releasedir,
};    

int
main(char[][] argv)
{
    Config.loadFromEnvironment();
    Log.root.add(new AppendConsole());
    enableLoggers();
    
    scope pool = new WorkerPool("fuse", 1, true);

    _root = TritonVFS.get.registerContainer("clint.gordoncarroll@gmail.com", 549169);
//    _root = TritonVFS.get.registerContainer("barbara-at-barbarastogner.com@mozy.test", 162958);

    scope (exit) TritonVFS.cleanup();
    
    char*[] argv2;
    argv2.length = argv.length;
    foreach (i, arg; argv) {
        argv2[i] = arg.ptr;
    }
    return fuse_main(argv.length, argv2.ptr, &ops, null);
}
