module mordor.kalypso.examples.mirror;

import tango.util.log.AppendConsole;

import mordor.common.config;
import mordor.common.log;
import mordor.common.streams.stream;
import mordor.common.streams.transfer;
import mordor.kalypso.difffs;
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
    
    static void mirrorSingleObject(IObject src, IObject dst, Stream dstStream = null)
    {
        Stream srcStream = src.open();
        if (srcStream !is null) {
            if (dstStream is null)
                dstStream = dst.open();
            transferStream(srcStream, dstStream);
            srcStream.close();
            dstStream.close();
        }
        dst[] = src[];
    }

    diffFS(src, dst,
        delegate void(IObject src, IObject dst) {
            mirrorSingleObject(src, dst);
        },
        delegate IObject(IObject src, IObject dstParent) {
            Stream stream;
            IObject dst = dstParent.create(src[], true, &stream);
            mirrorSingleObject(src, dst, stream);
            return dst;
        },
        delegate IObject(IObject dst, IObject srcParent) {
            dst._delete();
            return null;
        });
}
