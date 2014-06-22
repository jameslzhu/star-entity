module star.component;

debug import std.stdio;

class Component
{
    static ulong[string] types;
    static ulong type(C)() @trusted
    {
        string name = C.classinfo.name;
        if ((name in types) is null)
        {
            types[name] = types.length;
            types.rehash();
        }
        return types[name];
    }

    static void clear() @trusted
    {
        types.clear();
    }
}
