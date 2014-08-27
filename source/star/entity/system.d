///
/// Defines an architecture to manage systems.
/// Systems must implement the System interface.
///
/// Copyright: Copyright (c) 2014 James Zhu.
///
/// License: MIT License (Expat). See accompanying file LICENSE.
///
/// Authors: James Zhu <github.com/jzhu98>
///

module star.entity.system;

import std.traits : fullyQualifiedName;

import star.entity.entity;
import star.entity.event;

/// A generic system, encapsulating game logic.
interface System
{
    /// Used to register events.
    void configure(EventManager events);

    /// Used to update entities.
    void update(EntityManager entities, EventManager events, double dt);
}

/// Manages systems and their execution.
class SystemManager
{
public:
    /// Constructor taking events and entities.
    this(EntityManager entityManager, EventManager eventManager) pure nothrow @safe
    {
        _entityManager = entityManager;
        _eventManager = eventManager;
    }

    /// Add a system to the manager.
    void add(S)(S system) pure nothrow @trusted if (is (S : System))
    in
    {
        assert(!(system.classinfo.name in _systems));
    }
    body
    {
        _systems[system.classinfo.name] = system;
        _systems.rehash();
    }

    /// Remove a system from the manager.
    void remove(S)(S system) pure nothrow @safe
    {
        _systems.remove(system.classinfo.name);
    }

    /// Return the specified system.
    S system(S)() pure nothrow @safe
    {
        auto sys = (S.classinfo.name in _systems);
        if (sys)
        {
            return *sys;
        }
        else
        {
            return null;
        }
    }

    /// Configure every system added to the manager.
    void configure()
    {
        foreach(system; _systems)
        {
            system.configure(_eventManager);
        }
        _configured = true;
    }

    /// Update entities with the specified system.
    void update(S)(double dt)
    in
    {
        assert(_configured);
    }
    body
    {
        _systems[S.classinfo.name].update(_entityManager, _eventManager, dt);
    }

private:
    EntityManager _entityManager;
    EventManager _eventManager;
    System[string] _systems;
    bool _configured = false;
}

unittest
{
    class MovementSystem : System
    {
        void configure(EventManager events) { }
        void update(EntityManager entities, EventManager events, double dt)
        {
            foreach(entity; entities.entities!(Position, Velocity)())
            {
                auto position = entity.component!Position();
                auto velocity = entity.component!Velocity();
                position.x += velocity.x * dt;
                position.y += velocity.y * dt;
            }
        }
    }
    
    class GravitySystem : System
    {
        void configure(EventManager events) { }
        void update(EntityManager entities, EventManager events, double dt)
        {
            foreach(entity; entities.entities!(Velocity, Gravity)())
            {
                auto gravity = entity.component!gravity();
                auto velocity = entity.component!Velocity();
                auto accel = gravity.accel * dt;
                if (antigravity)
                {
                    accel = -accel;
                }
                velocity.y += accel;
            }
        }
    private:
        bool antigravity = false;
    }
    
    auto engine = new Engine;
    engine.systems.add(new MovementSystem);
    engine.systems.add(new GravitySystem);
    
    engine.systems.update!GravitySystem;
    engine.systems.update!MovementSystem;
}
