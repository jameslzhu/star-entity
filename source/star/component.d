module star.component;

import std.stdio;

class Component
{
    static ulong[string] types;
    static ulong type(C)()
    {
        string name = typeid(C).toString();
        if ((name in types) is null)
        {
            types[name] = types.length;
        }
        return types[name];
    }
}
