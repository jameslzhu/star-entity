module star.entity;

import core.vararg;
import std.stdio;
import std.container;

import star.component;

struct ID
{
public:
    this(ulong id)
    {
        _id = id;
    }

    this(uint index, uint tag)
    {
        _id = cast(ulong) index << 32UL | (cast(ulong) tag);
    }

    @property uint index()
    {
        return cast(uint)(_id >> 32UL);
    }

    @property uint tag()
    {
        return cast(uint) (_id);
    }

    bool opEquals()(auto ref const ID other) const
    {
        return _id == other._id;
    }

    int opCmp(ref const ID other) const
    {
        if (_id > other._id)
        {
            return 1;
        }
        else if (_id == other._id)
        {
            return 0;
        }
        else
        {
            return -1;
        }
    }

private:
    ulong _id;
}

static immutable ID INVALID = ID(-1, 0);

unittest
{
    ID id1 = ID(10, 1);
    ID id2 = ID(11, 2);
    assert(id1.index == 10U);
    assert(id1.tag == 1U);
    assert(id2.index == 11U);
    assert(id2.tag == 2U);
    assert(id1 < id2);
    assert(id1 != id2);
}

class Entity
{
public:
    this()
    {
        invalidate();
    }

    this(EntityManager manager, ID id)
    {
        _manager = manager;
        _id = id;
    }

    void add(C)()
    {
        _manager.addComponent!C(_id);
    }

    void add(C)(C component)
    {
        _manager.addComponent!C(_id, component);
    }

    void remove(C)()
    {
        if (hasComponent!C()) {
            _manager.remove!C(_id);
        }
    }

    bool hasComponent(C)()
    {
        return _manager.hasComponent!C(_id);
    }

    C component(C)()
    {
        return _manager.component!C(_id);
    }

    void destroy()
    {
        _manager.destroy(_id);
    }

    bool valid()
    {
        if (_manager is null)
        {
            return false;
        }
        else
        {
            return _manager.valid(_id);
        }
    }

    void invalidate()
    {
        _manager = null;
        _id = INVALID;
    }
private:
    EntityManager _manager;
    ID _id;
}

class EntityManager
{
public:
    this()
    {
        _indexCounter = 0U;
    }

    Entity create()
    {
        uint index, tag;
        if (_freeIndices.empty())
        {
            index = _indexCounter;
            _indexCounter++;
            _entityTags.length = _indexCounter;
            _componentMasks.length = _indexCounter;
            _entityTags[index] = 1;
            tag = 1;

            foreach (component; _components)
            {
                component.length = _indexCounter;
            }
        }
        else
        {
            index = _freeIndices.front();
            _freeIndices.removeFront();
            tag = _entityTags[index];
        }

        auto entity = new Entity(this, ID(index, tag));
        return entity;
    }

    Entity get(uint index)
    {
        assert(index < _indexCounter);
        return new Entity(this, ID(index, _entityTags[index]));
    }

    void destroy(ID id)
    {
        if (valid(id))
        {
            // Invalidate all handles by incrementing tag
            _entityTags[id.index]++;

            // Add index to free list
            _freeIndices.insertFront(id.index);

            // Remove all components
            foreach(component; _components)
            {
                component[id.index] = null;
            }

            // Clear the component bitmask
            _componentMasks[id.index].clear();
        }
    }

    void addComponent(C)(ID id, C component)
    {
        assert(valid(id));
        assert(!hasComponent!C(id));
        accomodateComponent!C();
        _components[Component.type!C()][id.index] = component;
    }

    void removeComponent(C)(ID id)
    {
        if (hasComponent!C(id))
        {
            _components[Component.type!C()][id.index] = null;
        }
    }

    bool hasComponent(C)(ID id)
    {
        /*writeln("Checking for component " ~ C.toString());*/
        assert(valid(id));

        /*writefln("Component array length: %s", _components.length);
        writefln("Has component type? %s", _components.length > Component.type!C());
        writefln("Component array is instantiated? %s", _components[Component.type!C()].length > 0);
        writefln("Index value: %s", _components[Component.type!C()][id.index]);*/
        if (Component.type!C() >= _components.length)
        {
            return false;
        }
        else if (_components[Component.type!C()][id.index] is null)
        {
            return false;
        }
        else
        {
            return true;
        }
    }

    C component(C)(ID id)
    {
        writeln("Getting component " ~ C.toString());
        if (hasComponent!C(id))
        {
            /*writeln("Component exists.");
            writefln("Component is not null? %s", (_components[Component.type!C()][id.index] !is null));
            writefln("Component type: %s", _components[Component.type!C()][id.index].toString());*/
            return cast(C) _components[Component.type!C()][id.index];
        }
        else
        {
            throw new Exception("Component" ~ C.toString() ~ "does not exist.");
        }
    }

    bool valid(ID id)
    {
        return (id.index < _indexCounter && _entityTags[id.index] == id.tag);
    }

private:
    void accomodateComponent(C)()
    {
        while (Component.type!C() >= _components.length)
        {
            _components.insert(make!(Array!Component)(new Component[_indexCounter]));
        }
    }

    // Tracks the last used entity index.
    uint _indexCounter;

    // Tracks entity indices recently freed.
    SList!uint _freeIndices;

    // Tracks entity versions (incremented when entity is destroyed)
    // for validity checking.
    uint[] _entityTags;

    // A nested array of entity components.
    Array!(Array!Component) _components;

    // Bitmasks of each entity's components.
    Array!(Array!bool) _componentMasks;
}
