///
/// Defines an architecture to manage entities, and several entity-related
/// events. Components must be defined as classes (for internal storage).
///
/// Copyright: Copyright (c) 2014 James Zhu.
///
/// License: MIT License (Expat). See accompanying file LICENSE.
///
/// Authors: James Zhu <github.com/jzhu98>
///

module star.entity.entity;

import std.container;
import std.conv;
import std.algorithm : filter;
import std.math : abs;

import star.entity.event;

/// An id encapsulates an index (unique ulong in an entity manager)
/// and a tag (to check if the entity is in sync (valid) with the manager).
struct ID
{
public:
    /// An invalid id, used for invalidating entities.
    static immutable ID INVALID = ID(0, 0);

    /// Construct an id from a 64-bit integer:
    /// A concatenated 32-bit index and 32-bit tag.
    this(ulong id) pure nothrow @safe
    {
        _id = id;
    }

    /// Construct an id from a 32-bit index and a 32-bit tag.
    this(uint index, uint tag) pure nothrow @safe
    {
        this(cast(ulong) index << 32UL | (cast(ulong) tag));
    }

    /// Return the index of the ID.
    inout(uint) index() inout pure nothrow @property @safe
    {
        return cast(uint)(_id >> 32UL);
    }

    unittest
    {
        auto id1 = ID(0x0000000100000002UL);
        auto id2 = ID(3U, 4U);
        assert(id1.index == 1U);
        assert(id2.index == 3U);
    }

    /// Return the tag of the ID.
    inout(uint) tag() inout pure nothrow @property @safe
    {
        return cast(uint) (_id);
    }

    unittest
    {
        auto id1 = ID((12UL << 32) + 13UL);
        auto id2 = ID(210U, 5U);
        assert(id1.tag == 13U);
        assert(id2.tag == 5U);
    }

    string toString() const pure @safe
    {
        return "ID(" ~ to!string(this.index) ~ ", " ~ to!string(this.tag) ~ ")";
    }

    /// Equals operator (check for equality).
    bool opEquals()(auto ref const ID other) const pure nothrow @safe
    {
        return _id == other._id;
    }

    unittest
    {
        auto id1 = ID(12U, 32U);
        auto id2 = ID(12U, 32U);
        auto id3 = ID(13U, 32U);
        assert(id1 == id2);
        assert(id1 != id3);
        assert(id2 != id3);
    }

    /// Comparison operators (check for greater / less than).
    int opCmp(ref const ID other) const pure nothrow @safe
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
        auto id1 = ID(1U, 10U);
        auto id2 = ID(1U, 11U);
        auto id3 = ID(2U, 1U);
        assert(id1 < id2);
        assert(id1 <= id3);
        assert(id3 >= id2);
        assert(id3 > id1);
    }

private:
    ulong _id;
}

/// An entity an aggregate of components (pure data), accessible with an id.
class Entity
{
public:
    /// Construct an entity with a manager reference and an ID.
    this(EntityManager manager, ID id) pure nothrow @safe
    {
        _manager = manager;
        _id = id;
    }

    /// Return the entity id.
    inout(ID) id() inout pure nothrow @property @safe
    {
        return _id;
    }

    unittest
    {
        auto entity = new Entity(null, ID(1, 2));
        assert(entity.id.index == 1);
        assert(entity.id.tag == 2);
    }

    /// Return the component added to this entity.
    inout(C) component(C)() inout pure nothrow @safe
    {
        return _manager.component!C(_id);
    }

    /// Check if the entity has a specific component.
    bool hasComponent(C)() pure nothrow @safe
    {
        return _manager.hasComponent!C(_id);
    }

    /// Add a component to the entity.
    void add(C)(C component) pure nothrow @safe
    {
        _manager.addComponent!C(_id, component);
    }

    /// Remove the component if the entity has it.
    void remove(C)() pure nothrow @safe
    {
        _manager.remove!C(_id);
    }

    /// Destroy this entity and invalidate all handles to this entity.
    void destroy() pure nothrow @safe
    {
        _manager.destroy(_id);
        invalidate();
    }

    /// Check if this handle is valid (points to the entity with the same tag).
    bool valid() pure nothrow @safe
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
    void invalidate() pure nothrow @safe
    {
        _manager = null;
        _id = ID.INVALID;
    }

    unittest
    {
        auto entity = new Entity(null, ID.INVALID);
        assert(!entity.valid());
    }

    /// Equals operator (check for equality).
    override bool opEquals(Object o) const
    {
        auto other = cast(Entity) o;
        return _id == other._id && _manager == other._manager;
    }

    unittest
    {
        auto entity1 = new Entity(null, ID(1, 1));
        auto entity2 = new Entity(null, ID(1, 1));
        auto entity3 = new Entity(null, ID(1, 2));
        auto entity4 = new Entity(null, ID(2, 1));

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

    /// Comparison operator.
    override int opCmp(Object o) const @safe
    {
        auto other = cast(Entity) o;
        return _id.opCmp(other._id);
    }

    unittest
    {
        auto entity1 = new Entity(null, ID(0, 1));
        auto entity2 = new Entity(null, ID(10, 230));
        auto entity3 = new Entity(null, ID(11, 200));

        assert(entity1 < entity2);
        assert(entity1 <= entity3);
        assert(entity3 > entity2);
        assert(entity2 >= entity1);
    }

private:
    EntityManager _manager;
    ID _id;
}

mixin template EntityEvent()
{
    this(Entity entity)
    {
        this.entity = entity;
    }
    Entity entity;
}

mixin template ComponentEvent(C)
{
    this(Entity entity, C component)
    {
        this.entity = entity;
        this.component = component;
    }
    Entity entity;
    C component;
}

struct EntityCreatedEvent
{
    mixin EntityEvent;
}

struct EntityDestroyedEvent
{
    mixin EntityEvent;
}

struct ComponentAddedEvent(C)
{
    mixin ComponentEvent!C;
}

struct ComponentRemovedEvent(C)
{
    mixin ComponentEvent!C;
}

/// Manages entities and their associated components.
class EntityManager
{
public:
    /// Construct an empty entity manager.
    this(EventManager events)
    {
        _indexCounter = 0U;
        _numEntities = 0U;
        _events = events;
    }

    /// A range over all entities in the manager.
    struct Range
    {
        /// Construct a range over this manager.
        private this(EntityManager manager, uint index = 0) pure nothrow @safe
        {
            _manager = manager;
            _index = index;
        }

        /// Return the number of entities to iterate over (including empty ones).
        size_t length() const pure nothrow @property @safe
        {
            return _manager.capacity;
        }

        /// Return if an only if the range cannot access any more entities.
        bool empty() const pure nothrow @property @safe
        {
            return _index >= _manager.capacity;
        }

        /// Return the current entity.
        Entity front() pure nothrow @property @safe
        {
            return _manager.entity(_index);
        }

        /// Access the next entity.
        void popFront() pure nothrow @safe
        {
            _index++;
        }

        /// Return a copy of this range.
        Range save() pure nothrow @safe
        {
            return Range(_manager, _index);
        }

        private EntityManager _manager;
        private uint _index;
    }

    /// Return a range over the entities.
    Range opSlice() pure nothrow @safe
    {
        return Range(this);
    }

    unittest
    {
        class Test
        {
            this(int x)
            {
                y = x;
            }
            int y;
        }

        auto manager = new EntityManager(new EventManager);
        auto entity1 = manager.create();
        auto entity2 = manager.create();

        entity1.add(new Test(3061));
        entity2.add(new Test(2015));

        foreach(entity; manager[])
        {
            if (entity == entity1)
            {
                assert(entity1.component!Test().y == 3061);
            }
            else if (entity == entity2)
            {
                assert(entity2.component!Test().y == 2015);
            }
            else
            {
                assert(0);
            }
        }
    }

    /// Create a range with only the entities with the specified components.
    auto entities(Components...)() pure nothrow @safe
    {
        foreach(C; Components)
        {
            if (!hasType!C())
            {
                return [];
            }
        }

        auto mask = componentMask!Components();

        bool hasComponents(Entity entity)
        {
            bool[] combinedMask = new bool[mask.length];
            combinedMask[] = componentMask(entity.id)[] & mask[];
            return combinedMask[] == mask[];
        }

        return this[].filter!(hasComponents)();
    }

    unittest
    {
        class Position
        {
            this(int x, int y)
            {
                this.x = x;
                this.y = y;
            }
            int x, y;
        }

        class Velocity
        {
            this(int x, int y)
            {
                this.x = x;
                this.y = y;
            }
            int x, y;
        }

        class Gravity
        {
            this(double acc)
            {
                accel = acc;
            }
            double accel;
        }

        auto manager = new EntityManager(new EventManager);

        auto entity1 = manager.create();
        entity1.add(new Position(2, 1));
        entity1.add(new Velocity(15, 4));

        auto entity2 = manager.create();
        entity2.add(new Velocity(-1, -3));
        entity2.add(new Gravity(10));

        auto entity3 = manager.create();
        entity3.add(new Gravity(-9.8));
        entity3.add(new Position(14, -9));

        auto positionEntities = manager.entities!Position();
        auto velocityEntities = manager.entities!Velocity();
        auto gravityEntities = manager.entities!Gravity();
        auto physicsEntities = manager.entities!(Position, Velocity, Gravity)();

        foreach (pos; positionEntities)
        {
            assert(pos == entity1 || pos == entity3);
            assert(pos != entity2);
        }

        foreach(vel; velocityEntities)
        {
            assert(vel == entity1 || vel == entity2);
            assert(vel != entity3);
        }

        foreach(grav; gravityEntities)
        {
            assert(grav == entity2 || grav == entity3);
            assert(grav != entity1);
        }

        assert(physicsEntities.empty());
    }

    /// Return the number of entities.
    size_t count() const pure nothrow @property @safe
    {
        return _numEntities;
    }

    /// Return the number of free entity indices.
    size_t free() const pure nothrow @property @safe
    {
        return capacity - count;
    }

    /// Return the maximum capacity of entities before needing reallocation.
    size_t capacity() const pure nothrow @property @safe
    {
        return _indexCounter;
    }

    /// Return if and only if there are no entities.
    bool empty() const pure nothrow @property @safe
    {
        return _numEntities == 0;
    }

    /// Return the entity with the specified index.
    Entity entity(uint index) pure nothrow @safe
    {
        return entity(id(index));
    }

    unittest
    {
        auto manager = new EntityManager(new EventManager);
        auto entity = manager.create();
        assert(entity == manager.entity(entity.id.index));
    }

    /// Return the entity with the specified (and valid) id.
    /// Returns null if the id is invalid.
    Entity entity(ID id) pure nothrow @safe
    out (result)
    {
        if (result !is null)
        {
            assert(valid(result.id));
        }
    }
    body
    {
        if (valid(id))
        {
            return new Entity(this, id);
        }
        else
        {
            return null;
        }
    }

    unittest
    {
        auto manager = new EntityManager(new EventManager);
        auto entity = manager.create();
        assert(entity == manager.entity(entity.id));
    }

    /// Return the id with the specified index.
    ID id(uint index) pure nothrow @safe
    {
        if (index < _indexCounter)
        {
            return ID(index, _entityTags[index]);
        }
        else
        {
            return ID(index, 0);
        }
    }

    unittest
    {
        auto manager = new EntityManager(new EventManager);
        auto entity = manager.create();
        assert(entity.id == manager.id(entity.id.index));
    }

    /// Check if this entity handle is valid - is not invalidated or outdated
    bool valid(ID id) const pure nothrow @safe
    {
        return (id.index < _indexCounter && _entityTags[id.index] == id.tag);
    }

    unittest
    {
        auto manager = new EntityManager(new EventManager);
        assert(!manager.valid(ID.INVALID));
        assert(manager.valid(manager.create().id));
    }

    /// Create an entity in a free slot.
    Entity create() pure nothrow @safe
    out (result)
    {
        assert(valid(result.id));
    }
    body
    {
        uint index;

        // Expand containers to accomodate new index
        if (_freeIndices.empty())
        {
            index = _indexCounter;
            accomodateEntity(_indexCounter);

            // Uninitialized value is 0, so any entities with tag 0 are invalid
            _entityTags[index] = 1;
        }
        // Fill unused index, no resizing necessary
        else
        {
            // Remove index from free indices list
            index = _freeIndices.front();
            _freeIndices.removeFront();
        }

        _numEntities++;
        _events.emit(EntityCreatedEvent());
        return new Entity(this, ID(index, _entityTags[index]));
    }

    unittest
    {
        auto manager = new EntityManager(new EventManager);
        auto entity1 = manager.create();
        auto entity2 = manager.create();

        assert(entity1.valid());
        assert(entity2.valid());
        assert(entity1 != entity2);

        entity1.invalidate();
        assert(!entity1.valid());
    }

    /// Destroy the specified entity and invalidate all handles to it.
    void destroy(ID id) pure nothrow @safe
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
            _freeIndices.insert(index);

            // Remove all components
            foreach(component; _components)
            {
                component[index] = null;
            }

            // Clear the component bitmask
            _componentMasks[index] = null;

            _numEntities--;
            _events.emit(EntityDestroyedEvent());
        }
    }

    unittest
    {
        auto manager = new EntityManager(new EventManager);
        auto entity1 = manager.create();
        auto entity2 = manager.create();
        auto entity3 = manager.create();

        assert(entity1.id == ID(0, 1));
        assert(entity2.id == ID(1, 1));
        assert(entity3.id == ID(2, 1));

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
        assert(entity4.id == ID(1, 2));
        assert(entity5.id == ID(0, 2));
    }

    /// Add a component to the specified entity.
    void addComponent(C)(ID id, C component) pure nothrow @safe
    in
    {
        assert(valid(id));
    }
    out
    {
        assert(hasComponent!C(id));
    }
    body
    {
        accomodateComponent!C();
        setComponent!C(id, component);
        setMask!C(id, true);
        _events.emit(ComponentAddedEvent!C());
    }

    /// Remove a component from the entity (no effects if it is not present).
    void removeComponent(C)(ID id) pure nothrow @safe
    out
    {
        assert(!hasComponent!C(id));
    }
    body
    {
        if (hasComponent!C(id))
        {
            setComponent(id, null);
            setMask!C(id, false);
            _events.emit(ComponentRemovedEvent!C());
        }
    }

    /// Check if the entity has the specified component.
    bool hasComponent(C)(const ID id) const pure nothrow @safe
    in
    {
        assert(valid(id));
    }
    body
    {
        return (hasType!C() && component!C(id) !is null);
    }

    /// Return the component associated with this entity.
    inout(C) component(C)(ID id) inout pure nothrow @safe
    in
    {
        assert(valid(id));
    }
    body
    {
        return cast(inout(C)) _components[type!C()][id.index];
    }

    unittest
    {
        class Position
        {
            this(int x, int y)
            {
                this.x = x;
                this.y = y;
            }
            int x, y;
        }

        class Jump
        {
            bool onGround = true;
        }

        auto manager = new EntityManager(new EventManager);
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

    /// Delete all entities and components.
    void clear() pure nothrow @safe
    {
        _indexCounter = 0U;
        _numEntities = 0U;
        _freeIndices.clear();
        _entityTags = null;
        _components = null;
        _componentTypes = null;
        _componentMasks = null;
    }

    unittest
    {
        class Position
        {
            this(int x, int y)
            {
                this.x = x;
                this.y = y;
            }
            int x, y;
        }

        class Velocity
        {
            this(int x, int y)
            {
                this.x = x;
                this.y = y;
            }
            int x, y;
        }

        class Gravity
        {
            this(double acc)
            {
                accel = acc;
            }
            double accel;
        }

        auto manager = new EntityManager(new EventManager);

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
        assert(abs(-9.8 - gravity.accel) < 1e-9);

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
    // Convenience function to set components.
    void setComponent(C)(ID id, C component) pure nothrow @safe
    {
        _components[type!C()][id.index] = component;
    }

    // Convenience function to set mask bits.
    void setMask(C)(ID id, bool value) pure nothrow @safe
    {
        _componentMasks[id.index][type!C()] = value;
    }

    // Reallocate space for a new component.
    void accomodateComponent(C)() pure nothrow @safe
    {
        if (!hasType!C())
        {
            addType!C();
            auto type = type!C();

            // Expand component array (new component - first dimension widens).
            if (_components.length < type + 1)
            {
                _components ~= new Object[_indexCounter];
            }

            // Expand all component masks to include new component.
            if (_componentMasks.length > 0 && _componentMasks[0].length < type + 1)
            {
                foreach (ref componentMask; _componentMasks)
                {
                    componentMask.length = type + 1;
                }
            }
        }
    }

    // Reallocate space for a new entity.
    void accomodateEntity(uint index) pure nothrow @safe
    {
        if (index >= _indexCounter)
        {
            // Expand entity tags.
            if (_entityTags.length < index + 1)
            {
                _entityTags.length = index + 1;
            }

            // Expand component mask array.
            if (_componentMasks.length < index + 1)
            {
                _componentMasks ~= new bool[_components.length];
            }

            // Expand all component arrays (new entity - second dimension widens).
            if (_components.length > 0 && _components[0].length < index + 1)
            {
                foreach (ref component; _components)
                {
                    component.length = index + 1;
                }
            }
        }
        _indexCounter = index + 1;
    }

    // Return a unique integer for every component type.
    size_t type(C)() inout pure nothrow @safe
    in
    {
        assert(hasType!C());
    }
    body
    {
        return _componentTypes[C.classinfo];
    }

    // Create a unique id for a new component type.
    void addType(C)() pure nothrow @trusted
    {
        if (!hasType!C())
        {
            _componentTypes[C.classinfo] = _componentTypes.length;
            _componentTypes.rehash();
        }
    }

    // Return if this component type has already been assigned a unique id.
    bool hasType(C)() const pure nothrow @safe
    {
        return (C.classinfo in _componentTypes) !is null;
    }

    // Return the component mask (bool array) of this entity.
    bool[] componentMask(ID id) pure nothrow @safe
    in
    {
        assert(valid(id));
    }
    body
    {
        return _componentMasks[id.index];
    }

    // Return the component mask with the specified components marked as true.
    bool[] componentMask(Components...)() pure nothrow @safe
    in
    {
        foreach(C; Components)
        {
            assert(type!C() < _components.length);
        }
    }
    body
    {
        bool[] mask = new bool[_components.length];
        foreach (C; Components)
        {
            mask[type!C()] = true;
        }
        return mask;
    }

    unittest
    {
        class Position { }
        class Velocity { }
        class Gravity { }

        auto manager = new EntityManager(new EventManager);
        auto entity = manager.create();
        entity.add(new Position());
        entity.add(new Velocity());
        entity.add(new Gravity());

        assert(manager.componentMask!(Position)() == [true, false, false]);
        assert(manager.componentMask!(Position, Velocity, Gravity)() == [true, true, true]);
    }

    // Debugging checks to ensure valid space for new entities and components.
    invariant()
    {
        assert(_numEntities <= _indexCounter);
        assert(_entityTags.length == _indexCounter);
        assert(_componentMasks.length == _indexCounter);
        assert(_components.length == _componentTypes.length);

        foreach(componentMask; _componentMasks)
        {
            assert(componentMask.length == _components.length);
        }

        foreach(ref componentArray; _components)
        {
            assert(componentArray.length == _indexCounter);
        }
    }

    // Tracks the actual number of entities.
    uint _numEntities;

    // Tracks the next unused entity index (i.e. capacity)..
    uint _indexCounter;

    // Tracks entity indices recently freed.
    SList!uint _freeIndices;

    // Tracks entity versions (incremented when entity is destroyed) for validity checking.
    uint[] _entityTags;

    // A nested array of entity components, ordered by component and then entity index.
    Object[][] _components;

    // A map associating each component class with a unique unsigned integer.
    size_t[ClassInfo] _componentTypes;

    // Bitmasks of each entity's components, ordered by entity and then by component bit.
    bool[][] _componentMasks;

    // Event manager.
    EventManager _events;
}
