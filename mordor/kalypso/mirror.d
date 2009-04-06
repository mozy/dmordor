module mordor.kalypso.mirror;

import tango.util.log.Log;

import mordor.common.applyiterator;
import mordor.common.containers.linkedlist;
import mordor.common.streams.stream;
import mordor.common.streams.transfer;
import mordor.common.stringutils;
import mordor.kalypso.vfs.helpers;
import mordor.kalypso.vfs.model;

private Logger _log, _logIterate;

static this()
{
    _log = Log.lookup("mordor.kalypso.mirror");
    _logIterate = Log.lookup("mordor.kalypso.mirror.iterate");
}

void mirror(IObject src, IObject dst)
{
    struct SrcAndDst 
    {
        IObject src;
        IObject dst;
    }
    LinkedList!(SrcAndDst) toMirror = new LinkedList!(SrcAndDst);

    void mirrorSingleObject(IObject src, IObject dst, bool includeMetadata = true, bool includeData = true, Stream dstStream = null)
    {
        _log.trace("Mirroring {} to {}", getFullPath(src), getFullPath(dst));
        if (includeData) {
            Stream srcStream = src.open();
            if (srcStream !is null) {
                if (dstStream is null)
                    dstStream = dst.open();
                transferStream(srcStream, dstStream);
                srcStream.close();
                dstStream.close();
            }
        }
        if (includeMetadata) {
            dst[] = src[];
        }
    }

    void mirrorChildren(IObject src, IObject dst)
    {
        auto orderedSrc = cast(IOrderedEnumerateObject)src;
        auto orderedDst = cast(IOrderedEnumerateObject)dst;
        if (orderedSrc !is null && orderedDst !is null) {
            scope srcIt = new ApplyIterator!(IObject)(&src.children);
            scope dstIt = new ApplyIterator!(IObject)(&dst.children);
            while (!srcIt.done || !dstIt.done) {
                if (srcIt.done) {
                    _logIterate.trace("Src iteration complete; dst iterating {}", getFullPath(dstIt.val));
                    _log.trace("Deleting {}", dstIt.val["name"].get!(string));
                    dstIt.val._delete();
                    ++dstIt;
                    continue;                    
                }
                if (dstIt.done) {
                    _logIterate.trace("Dst iteration complete; creating {}", getFullPath(srcIt.val));
                    _log.trace("Creating {}", srcIt.val["name"].get!(string));
                    Stream newStream;
                    IObject newDst = dst.create(srcIt.val[], true, &newStream);
                    mirrorSingleObject(srcIt.val, newDst, true, true, newStream);
                    toMirror.append(SrcAndDst(srcIt.val, newDst));
                    ++srcIt;
                    continue;
                }
                _logIterate.trace("Src iterating {}, dst iterating {}", getFullPath(srcIt.val), getFullPath(dstIt.val));
                string srcName = srcIt.val["name"].get!(string);
                string dstName = dstIt.val["name"].get!(string);
                if (srcName < dstName) {
                    _log.trace("Creating {}", srcName);
                    Stream newStream;
                    IObject newDst = dst.create(srcIt.val[], true, &newStream);
                    mirrorSingleObject(srcIt.val, newDst, true, true, newStream);
                    toMirror.append(SrcAndDst(srcIt.val, newDst));
                    ++srcIt;
                    continue;
                } else if (srcName == dstName) {
                    mirrorSingleObject(srcIt.val, dstIt.val);
                    toMirror.append(SrcAndDst(srcIt.val, dstIt.val));
                    ++srcIt; ++dstIt;
                    continue;
                } else /* if (dstName < srcName) */ {
                    _log.trace("Deleting {}", dstName);
                    dstIt.val._delete();
                    ++dstIt;
                    continue;
                }
            }
        } else {
            //assert(false, "not implemented");
        }        
    }
    
    mirrorSingleObject(src, dst);
    mirrorChildren(src, dst);
    while (!toMirror.empty()) {
        auto next = toMirror.begin.val;
        toMirror.erase(toMirror.begin);
        mirrorChildren(next.src, next.dst);
    }
}

debug (mirror) {
    import tango.util.log.AppendConsole;

    import mordor.common.config;
    import mordor.common.log;
    import mordor.kalypso.vfs.manager;
    
    void main(string[] args)
    {
        Config.loadFromEnvironment();
        Log.root.add(new AppendConsole());
        enableLoggers();
    
        IVFS vfs = cast(IVFS)VFSManager.get.find("native");
        assert(vfs !is null);
        
        IObject src = vfs.find(args[1]);
        IObject dst = vfs.find(args[2]);
        mirror(src, dst);
    }
}
