module mordor.kalypso.vfs.model;

import mordor.common.streams.stream;
import mordor.common.stringutils;

interface IVFS : IObject
{
}

interface IObject
{
    int children(int delegate(ref IObject) dg);
    int references(int delegate(ref IObject) dg);
    int properties(int delegate(ref tstring) dg);
    tstring opIndex(tstring property);
    void opIndexAssign(tstring value, tstring property);
    void _delete();
    Stream open();
}
