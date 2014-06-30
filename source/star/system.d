module star.system;

import star.entity;
import star.event;

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
    this(EntityManager entityManager, EventManager eventManager)
    {
        _entityManager = entityManager;
        _eventManager = eventManager;
    }

    /// Add a system to the manager.
    void add(System system)
    in
    {
        assert((system.classinfo.name in _systems) is null);
    }
    body
    {
        _systems[system.classinfo.name] = system;
        _systems.rehash();
    }

    /// Remove a system from the manager.
    void remove(System system)
    {
        _systems.remove(system.classinfo.name);
    }

    /// Return the specified system.
    S system(S)()
    {
        auto sys = (S.classinfo.name in _systems);
        if (sys !is null)
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
        _systems[S.classinfo.name].update(_entitySystem, dt);
    }

private:
    EntityManager _entityManager;
    EventManager _eventManager;
    System[string] _systems;
    bool _configured = false;
}
