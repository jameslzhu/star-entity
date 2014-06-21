module star.entity;

import core.vararg;
import std.stdio;
import std.container;
import std.array;

debug import std.stdio;

import star.component;

/// An entity an aggregate of components (pure data), accessible with an id.
class Entity
{
public:
    /// An id encapsulates an index (unique ulong in an entity manager)
    /// and a tag (to check if the entity is in sync (valid) with the manager).
    struct ID
    {
    public:
        /// Construct an id from a 64-bit integer:
        /// A concatenated 32-bit index and 32-bit tag.
        this(ulong id)
        {
            _id = id;
        }

        /// Construct an id from a 32-bit index and a 32-bit tag.
        this(uint index, uint tag)
        {
            this(cast(ulong) index << 32UL | (cast(ulong) tag));
        }

        /// Return the index of the Entity.ID.
        @property inout(uint) index() inout
        {
            return cast(uint)(_id >> 32UL);
        }

        unittest
        {
            auto id1 = Entity.ID(0x0000000100000002UL);
            auto id2 = Entity.ID(3U, 4U);

            assert(id1.index == 1U);
            assert(id2.index == 3U);
        }

        /// Return the tag of the Entity.ID.
        @property inout(uint) tag() inout
        {
            return cast(uint) (_id);
        }

        unittest
        {
            auto id1 = Entity.ID((12UL << 32) + 13UL);
            auto id2 = Entity.ID(210U, 5U);

            assert(id1.tag == 13U);
            assert(id2.tag == 5U);
        }

        /// Equals operator (check for equality).
        bool opEquals()(auto ref const Entity.ID other) const
        {
            return _id == other._id;
        }

        unittest
        {
            auto id1 = Entity.ID(12U, 32U);
            auto id2 = Entity.ID(12U, 32U);
            auto id3 = Entity.ID(13U, 32U);
            assert(id1 == id2);
            assert(id1 != id3);
            assert(id2 != id3);
        }

        /// Comparison operators (check for greater / less than).
        int opCmp(ref const Entity.ID other) const
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

        unittest
        {
            auto id1 = Entity.ID(1U, 10U);
            auto id2 = Entity.ID(1U, 11U);
            auto id3 = Entity.ID(2U, 1U);
            assert(id1 < id2);
            assert(id1 <= id3);
            assert(id3 >= id2);
            assert(id3 > id1);
        }

    private:
        ulong _id;
    }

    /// An invalid id, used for invalidating entities.
    static immutable Entity.ID INVALID = Entity.ID(0, 0);

    /// Construct an entity with a manager reference and an Entity.ID.
    this(EntityManager manager, Entity.ID id)
    {
        _manager = manager;
        _id = id;
    }

    /// Return the entity id.
    @property inout(Entity.ID) id() inout
    {
        return _id;
    }

    unittest
    {
        auto entity = new Entity(null, Entity.ID(1, 2));
        assert(entity.id.index == 1);
        assert(entity.id.tag == 2);
    }

    /// Return the component added to this entity.
    inout(C) component(C)() inout
    {
        return _manager.component!C(_id);
    }

    unittest
    {
        class TestComponent : Component
        {
            this(int value)
            {
                _value = value;
            }
            int _value;
        }

        auto manager = new EntityManager();
        auto entity = manager.create();
        auto component = new TestComponent(2);

        entity.add(component);
        auto returnedComponent = entity.component!TestComponent();
        assert(returnedComponent._value == 2);
        assert(component._value == returnedComponent._value);
    }

    /// Check if the entity has a specific component.
    bool hasComponent(C)()
    {
        return _manager.hasComponent!C(_id);
    }

    /// Add a component to the entity.
    void add(C)(C component)
    {
        _manager.addComponent!C(_id, component);
    }

    /// Remove the component if the entity has it.
    void remove(C)()
    {
        _manager.remove!C(_id);
    }

    /// Destroy this entity and invalidate all handles to this entity.
    void destroy()
    {
        _manager.destroy(_id);
        invalidate();
    }

    /// Check if this handle is valid (points to the entity with the same tag).
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

    /// Invalidate this entity handle (but not other handles).
    void invalidate()
    {
        _manager = null;
        _id = INVALID;
    }

private:
    EntityManager _manager;
    Entity.ID _id;
}

/// Manages entities and their associated components.
class EntityManager
{
public:
    /// Construct an empty entity manager.
    this()
    {
        _indexCounter = 0U;
    }

    ~this()
    {
        reset();
    }

    /// Create an entity.
    Entity create()
    out (result)
    {
        assert(valid(result.id));
    }
    body
    {
        uint index, tag;
        if (_freeIndices.empty())
        {
            _entityTags.reserve(_indexCounter + 1);
            _componentMasks.reserve(_indexCounter + 1);

            index = _indexCounter++;
            _entityTags[index] = tag = 1;

            foreach (component; _components)
            {
                component.reserve(_indexCounter);
            }
        }
        else
        {
            index = _freeIndices.front();
            _freeIndices.removeFront();
            tag = _entityTags[index];
        }

        auto entity = new Entity(this, Entity.ID(index, tag));
        return entity;
    }

    /// Return the entity with the specified index.
    Entity get(uint index)
    in
    {
        assert(index < _indexCounter);
    }
    out (result)
    {
        assert(valid(result.id));
    }
    body
    {
        return new Entity(this, Entity.ID(index, _entityTags[index]));
    }

    /// Check if this entity handle is valid - is not invalidated and
    bool valid(Entity.ID id) const
    {
        return (id.index < _indexCounter && _entityTags[id.index] == id.tag);
    }

    /// Destroy the specified entity and invalidate all handles to it.
    void destroy(Entity.ID id)
    out
    {
        assert(!valid(id));
    }
    body
    {
        if (valid(id))
        {
            auto index = id.index;
            // Invalidate all handles by incrementing tag
            _entityTags[index]++;

            // Add index to free list
            _freeIndices.insertFront(index);

            // Remove all components
            foreach(component; _components)
            {
                component[index] = null;
            }

            // Clear the component bitmask
            _componentMasks[index].clear();
        }
    }

    /// Add a component to the specified entity.
    void addComponent(C)(Entity.ID id, C component)
    in
    {
        assert(valid(id));
        assert(!hasComponent!C(id));
    }
    out
    {
        assert(hasComponent!C(id));
    }
    body
    {
        accomodateComponent!C();
        setComponent!C(id, component);
        _componentMasks[id.index][Component.type!C()] = true;
    }

    /// Remove a component from the entity (no effects if it is not present).
    void removeComponent(C)(Entity.ID id)
    out
    {
        assert(!hasComponent!C(id));
    }
    body
    {
        if (hasComponent!C(id))
        {
            setComponent(id, null);
            _componentMasks[id.index][Component.type!C()] = false;
        }
    }

    /// Check if the entity has the specified component.
    bool hasComponent(C)(const Entity.ID id)
    in
    {
        assert(valid(id));
    }
    body
    {
        return (Component.type!C() < _components.length &&
            component!C(id) !is null);
    }

    /// Return the component associated with this entity.
    inout(C) component(C)(Entity.ID id) inout
    in
    {
        assert(valid(id));
    }
    body
    {
        return cast(C) _components[Component.type!C()][id.index];
    }

    inout(Array!bool) componentMask(Entity.ID id) inout
    in
    {
        assert(valid(id));
    }
    body
    {
        return _componentMasks[id.index];
    }

    /// Delete all entities and components.
    void reset()
    {
        _indexCounter = 0U;
        _freeIndices.clear();
        _entityTags.clear();
        _components.clear();
        _componentMasks.clear();
    }

private:
    void accomodateComponent(C)()
    {
        auto extension = Component.type!C() - _components.length + 1;
        if (extension > 0)
        {
            _components.reserve(Component.type!C() + 1);
            foreach (ref component; _components)
            {
                component.reserve(_indexCounter);
            }
            foreach (ref componentMask; _componentMasks)
            {
                componentMask.reserve(_components.length);
            }
        }
    }

    void setComponent(C)(Entity.ID id, Component component)
    {
        _components[Component.type!C()][id.index] = component;
    }

    invariant()
    {
        assert(_entityTags.capacity >= _indexCounter);
        assert(_componentMasks.capacity >= _indexCounter);
    }

    // Tracks the next unused entity index.
    uint _indexCounter;

    // Tracks entity indices recently freed.
    SList!uint _freeIndices;

    // Tracks entity versions (incremented when entity is destroyed) for validity checking.
    Array!uint _entityTags;

    // A nested array of entity components, ordered by component and then entity index.
    Array!(Array!Component) _components;

    // Bitmasks of each entity's components.
    Array!(Array!bool) _componentMasks;
}
