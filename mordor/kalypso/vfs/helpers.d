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

Variant[string] getProperties(IObject object)
{
    Variant[string] properties;
    foreach(p, c, s; &object.properties)
    {
        properties[p] = object[p];
    }
    return properties;
}
