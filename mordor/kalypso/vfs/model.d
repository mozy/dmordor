module mordor.kalypso.vfs.model;

import tango.core.Variant;

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
    Variant opIndex(tstring property);
    void opIndexAssign(Variant value, tstring property);
    void _delete();
    Stream open();
}
