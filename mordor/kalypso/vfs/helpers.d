module mordor.kalypso.vfs.helpers;

import tango.core.Variant;

import mordor.common.stringutils;
import mordor.kalypso.vfs.model;

string getFullPath(IObject object)
{
    return getPathRelativeTo(object, null, true);    
}

string getPathRelativeTo(IObject object, IObject root, bool includeRootSlash)
{
    size_t totalLength;
    size_t writtenTo;
    IObject copy = object;
    string result;
    
    void recurse(IObject object) {
        if (object is root) {
            result.length = totalLength;
            if (!includeRootSlash)
                result = result[1..$];
            return;
        }
        string thisName = object["name"].get!(string);
        totalLength += thisName.length + 1;
        recurse(object.parent);
        result[writtenTo++] = '/';
        result[writtenTo..writtenTo+thisName.length] = thisName[];
        writtenTo += thisName.length;
    }
    recurse(object);
    return result;
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
