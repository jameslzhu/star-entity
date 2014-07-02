///
/// Convenience class wrapping the entire ECS framework.
///
/// Copyright: Copyright (c) 2014 James Zhu.
///
/// License: MIT License (Expat). See accompanying file LICENSE.
///
/// Authors: James Zhu <github.com/jzhu98>
///

module star.entity.engine;

import star.entity.entity;
import star.entity.system;
import star.entity.event;

/// Encapsulates components, systems, entities, and events.
class Engine
{
    this()
    {
        events = new EventManager;
        entities = new EntityManager(events);
        systems = new SystemManager(entities, events);
    }

    EventManager events;
    EntityManager entities;
    SystemManager systems;
}
