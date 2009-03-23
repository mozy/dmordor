module mordor.kalypso.vfs.helpers;

import tango.core.Variant;

import mordor.common.stringutils;
import mordor.kalypso.vfs.model;

string getFullPath(IObject object)
{
    size_t totalLength;
    size_t writtenTo;
    IObject copy = object;
    string ret;
    
    void recurse(IObject object) {
        if (object is null) {
            ret.length = totalLength;
            return;
        }
        string thisName = object["name"].get!(string);
        totalLength += thisName.length + 1;
        recurse(object.parent);
        ret[writtenTo++] = '/';
        ret[writtenTo..writtenTo+thisName.length] = thisName[];
        writtenTo += thisName.length;
    }
    recurse(object);
    return ret;
}

Variant[] getProperties(IObject object, string[] properties)
{
    Variant[] values;
    values.length = properties.length;
    foreach(i, p; properties) {
        values[i] = object[p];
    }
    return values;
}
