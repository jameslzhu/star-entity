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

        @property string toString()
        {
            return "ID(" ~ std.conv.to!string(this.index) ~ ", " ~ std.conv.to!string(this.tag) ~ ")";
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

    /// Equals operator (check for equality).
    override bool opEquals(Object o) const
    {
        auto other = cast(Entity) o;
        return _id == other._id && _manager == other._manager;
    }

    unittest
    {
        auto entity1 = new Entity(null, Entity.ID(1, 1));
        auto entity2 = new Entity(null, Entity.ID(1, 1));
        auto entity3 = new Entity(null, Entity.ID(1, 2));
        auto entity4 = new Entity(null, Entity.ID(2, 1));

        assert(entity1 == entity1);
        assert(entity1 == entity2);
        assert(entity1 != entity3);
        assert(entity1 != entity4);

        assert(entity2 == entity1);
        assert(entity2 == entity2);
        assert(entity2 != entity3);
        assert(entity2 != entity4);

        assert(entity3 != entity1);
        assert(entity3 != entity2);
        assert(entity3 == entity3);
        assert(entity3 != entity4);

        assert(entity4 != entity1);
        assert(entity4 != entity2);
        assert(entity4 != entity3);
        assert(entity4 == entity4);
    }

    override int opCmp(Object o) const
    {
        auto other = cast(Entity) o;
        return _id.opCmp(other._id);
    }

    unittest
    {
        auto entity1 = new Entity(null, Entity.ID(0, 1));
        auto entity2 = new Entity(null, Entity.ID(10, 230));
        auto entity3 = new Entity(null, Entity.ID(11, 200));

        assert(entity1 < entity2);
        assert(entity1 <= entity3);
        assert(entity3 > entity2);
        assert(entity2 >= entity1);
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

    /// Check if this entity handle is valid - is not invalidated or outdated
    bool valid(Entity.ID id) const
    {
        return (id.index < _indexCounter && _entityTags[id.index] == id.tag);
    }

    unittest
    {
        auto manager = new EntityManager();
        assert(!manager.valid(Entity.INVALID));
        assert(manager.valid(manager.create().id));
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

        // Expand containers to accomodate new index
        if (_freeIndices.empty())
        {
            accomodateEntity(_indexCounter);
            index = _indexCounter++;

            // Uninitialized value is 0, so any entities with tag 0 are invalid
            _entityTags[index] = tag = 1;
        }
        // Fill unused index, no resizing necessary
        else
        {
            // Remove index from free indices list
            index = _freeIndices.front();
            _freeIndices.removeFront();
            tag = _entityTags[index];
        }

        return new Entity(this, Entity.ID(index, tag));
    }

    unittest
    {
        auto manager = new EntityManager();
        auto entity1 = manager.create();
        auto entity2 = manager.create();

        assert(entity1.valid());
        assert(entity2.valid());
        assert(entity1 != entity2);

        entity1.invalidate();
        assert(!entity1.valid());
    }

    /// Return the entity with the specified index.
    Entity get(Entity.ID id)
    in
    {
        assert(valid(id));
    }
    out (result)
    {
        assert(valid(result.id));
    }
    body
    {
        return new Entity(this, Entity.ID(id.index, _entityTags[id.index]));
    }

    unittest
    {
        auto manager = new EntityManager();
        auto entity = manager.create();
        assert(entity == manager.get(entity.id));
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

    unittest
    {
        auto manager = new EntityManager();
        auto entity1 = manager.create();
        auto entity2 = manager.create();
        auto entity3 = manager.create();

        assert(entity1.id == Entity.ID(0, 1));
        assert(entity2.id == Entity.ID(1, 1));
        assert(entity3.id == Entity.ID(2, 1));

        // Two methods of destroying entities
        manager.destroy(entity1.id);
        entity2.destroy();

        assert(!entity1.valid());
        assert(!entity2.valid());
        assert(entity3.valid());

        auto entity4 = manager.create();
        auto entity5 = manager.create();

        assert(entity3.valid());
        assert(entity4.valid());
        assert(entity5.valid());
        assert(entity4.id == Entity.ID(1, 2));
        assert(entity5.id == Entity.ID(0, 2));
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

    unittest
    {
        class Position : Component
        {
            this(int x, int y)
            {
                this.x = x;
                this.y = y;
            }
            int x, y;
        }

        class Jump : Component
        {
            bool onGround = true;
        }

        auto manager = new EntityManager();
        auto entity = manager.create();
        auto position = new Position(1001, -19);
        auto jump = new Jump();

        entity.add(position);
        manager.addComponent(entity.id, jump);
        assert(entity.hasComponent!Position());
        assert(entity.hasComponent!Jump());
        assert(position == entity.component!Position());
        assert(jump == manager.component!Jump(entity.id));
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
    bool hasComponent(C)(const Entity.ID id) const
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
        return cast(inout(C)) _components[Component.type!C()][id.index];
    }

    /// Return the component mask (bool array) of this entity.
    inout(bool[]) componentMask(Entity.ID id) inout
    in
    {
        assert(valid(id));
    }
    body
    {
        return _componentMasks[id.index];
    }

    /// Delete all entities and components.
    void clear()
    {
        _indexCounter = 0U;
        _freeIndices.clear();
        _entityTags = null;
        _components = null;
        _componentMasks = null;
    }

    unittest
    {
        class Position : Component
        {
            this(int x, int y)
            {
                this.x = x;
                this.y = y;
            }
            int x, y;
        }

        class Velocity : Component
        {
            this(int x, int y)
            {
                this.x = x;
                this.y = y;
            }
            int x, y;
        }

        class Gravity : Component
        {
            this(double acc)
            {
                accel = acc;
            }
            double accel;
        }

        auto manager = new EntityManager();

        auto entity1 = manager.create();
        entity1.add(new Position(2, 1));

        auto entity2 = manager.create();
        entity2.add(new Velocity(-1, -3));

        auto entity3 = manager.create();
        entity3.add(new Gravity(-9.8));

        auto position = entity1.component!Position();
        auto velocity = entity2.component!Velocity();
        auto gravity = entity3.component!Gravity();

        assert(position.x == 2 && position.y == 1);
        assert(velocity.x == -1 && velocity.y == -3);
        assert(std.math.abs(-9.8 - gravity.accel) < 1e-9);

        manager.clear();
        assert(!entity1.valid());
        assert(!entity2.valid());
        assert(!entity3.valid());
        assert(manager._indexCounter == 0);
        assert(manager._freeIndices.empty);
        assert(manager._entityTags.length == 0);
        assert(manager._components.length == 0);
        assert(manager._componentMasks.length == 0);

        auto entity4 = manager.create();
        assert(entity4.valid());
        assert(entity4.id.index == 0);
    }

private:
    void accomodateComponent(C)()
    {
        _components.reserve(Component.type!C() + 1);
        _components.length = _components.capacity;
        foreach (ref component; _components)
        {
            component.reserve(_indexCounter);
            component.length = component.capacity;
        }
        foreach (ref componentMask; _componentMasks)
        {
            componentMask.reserve(_components.length);
            componentMask.length = componentMask.capacity;
        }
    }

    void setComponent(C)(Entity.ID id, Component component)
    {
        _components[Component.type!C()][id.index] = component;
    }

    void accomodateEntity(uint index)
    {
        if (index >= _indexCounter)
        {
            _entityTags.reserve(index + 1);
            _entityTags.length = _entityTags.capacity;

            _componentMasks.reserve(index + 1);
            _componentMasks.length = _componentMasks.capacity;

            foreach (ref component; _components)
            {
                component.reserve(index + 1);
                component.length = component.capacity;
            }

        }
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
    uint[] _entityTags;

    // A nested array of entity components, ordered by component and then entity index.
    Component[][] _components;

    // Bitmasks of each entity's components, ordered by entity and then by component bit.
    bool[][] _componentMasks;
}
