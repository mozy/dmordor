module mordor.kalypso.vfs.helpers;

import mordor.common.stringutils;
import mordor.kalypso.vfs.model;

tstring getFullPath(IObject object)
{
    size_t totalLength;
    size_t writtenTo;
    IObject copy = object;
    tstring ret;
    
    void recurse(IObject object) {
        if (object is null) {
            ret.length = totalLength;
            return;
        }
        tstring thisName = object["name"].get!(tstring);
        totalLength += thisName.length + 1;
        recurse(object.parent);
        ret[writtenTo++] = '/';
        ret[writtenTo..writtenTo+thisName.length] = thisName[];
        writtenTo += thisName.length;
    }
    recurse(object);
    return ret;
}
