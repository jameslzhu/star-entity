star-entity
===========

An open-source entity-component-system, written in D.
**star-entity** offers component management, entity creation, event delivery,
and system management.

This framework is heavily based upon
[EntityX](https://github.com/alecthomas/entityx) by alecthomas and some ideas
from [Ashley](https://github.com/libgdx/ashley/).

## Overview
The framework is modeled after the Entity-Component-System (ECS) architecture, a form
of decomposition that decouples logic and data, and using composition instead
of inheritance to allow greater flexibility and modular functionality.

Essentially, data is condensed into a component, a simple data class, and
an `Entity` is simply an aggregate of these components.
`Systems` encapsulates logic and operates upon a specific subset of entities,
namely those with specific components.
`Events` allow for system interaction without tight coupling.

As an example: a game might have players with *health*, *sword*, *speed*,
*position*, *bounds* and *sprite*, and walls would have *position*, *bounds*,
and *sprite*.

The graphics system would need only the *position* and *sprite* components,
whereas the physics might require the *position* and *bounds*.

If the player collided with the wall, the physics system might emit a
*collision* event.

The article
[Evolve your Hierarchy](https://cowboyprogramming.com/2007/01/05/evolve-your-heirachy/)
offers a great introduction and overview of ECS frameworks and how they can
make your code more modular, more extensible, and simpler.

## Building
This project uses the DUB build system, found [here](https://code.dlang.org/download).

To build the project, simply run in the top-level directory

```sh
dub build --build=release
```

To use this project as a dependency, add this to your **dub.json**:

```json
"dependencies": {
    "star-entity": ">=1.0.0"
}
```

## Usage

Some example code to implement the aforementioned physics system:

### Entities
`star.entity.Entity` wraps on opaque index (uint) that is used to
add, remove, or retrieve components in its corresponding
`star.entity.EntityManager`.

Creating an entity is done by

```c++
import star.entity;

auto engine = new Engine;
auto entity = engine.entities.create();
```

The entity is destroyed by
```
entity.destroy();
```

#### Implementation details:
- The entity wraps an index (uint) and a tag (uint).
- `Entity` acts as a *handle*, meaning that multiple `Entities` may refer to
  the same entity.
- `Entity.invalidate()` is used to invalidate the handle, meaning it can
  no longer be used. The data, however, is still intact and is still accessible.
- `Entity.destroy()` is used to invalidate all handles and deallocate the data,
  freeing the index for reuse by a new entity.
- `Entity.valid()` should always be used to check validity before usage.
- Destruction is done by incrementing the tag; thus making all current
  `Entities` tags unequal and invalid.

### Components
Components should be designed to hold data, and have few methods (if any).  
At the moment, they must be implemented as **classes** (for internal storage), but
in the future I hope to implement templates properly to enable using POD
structs.

#### Creation
Continuing our previous example of a physics system:
```c++
class Position
{
    this(double x, double y) { this.x = x; this.y = y; }
    double x, y;
}

class Velocity
{
    this(double x, double y) { this.x = x; this.y = y; }
    double x, y;
}

class Gravity
{
    this(double accel) { this.accel = accel; }
    double accel;
}
```

#### Assignment
To associate these components with an entity, call `Entity.add(C)(C component)`:

```c++
entity.add(new Position(1.0, 2.0));
entity.add(new Velocity(15.0, -2.0));
entity.add(new Gravity(-9.8));
```

#### Querying
To access all entities with specific components, use
`EntityManager.entities!(Components...)()`:

```cs
foreach(entity; engine.entities.entities!(Position, Velocity))
{
    // Do work with entities containing Position and Velocity components
}
```

To access a specific entity's component, use
`Entity.component!(C)()`:

```c++
auto velocity = entity.component!Velocity();
```

### Systems
Systems implement logic and behavior.  
They must implement the `star.system.System` interface
(`configure()` and `update()`)

Continuing our physics example, let's implement a movement and gravity system:

```cs
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
```

Adding them to the system manager is quite simple:

```c++
engine.systems.add(new MovementSystem);
engine.systems.add(new GravitySystem);
```

### Events
Events are objects (structs or classes) that indicate something has occured,
e.g. a collision, button press, mouse event, etc.  
Instead of setting component flags, events offer a simple way of notifying
other classes of infrequent data, using callbacks.

#### Event types

Events can be either structs or classes.
No interfaces or class extension necessary.

```css
struct Collision
{
    Entity first, second;
}
```

#### Event emission

Our collision system will emit a Collision object if two objects collide.  
(Ignore the slow algorithm below without any of that fancy "spatial
partitioning". This is just an example.)

```cs
class CollisionSystem : System
{
    void configure(EventManager events) { }
    void update(EntityManager entities, EventManager events, double dt)
    {
        foreach(first; entities.entities!(Position))
        {
            foreach(second; entities.entites!(Position)())
            {
                if (collides(first, second))
                {
                    events.emit(Collision {first, second});
                }
            }
        }
    }
}
```

#### Event subscription

Classes intending to receive specific events should implement the
`Receiver(E)` interface, for events of type E.

```cs
class DebugSystem : System, Receiver!Collision
{
    void configure(EventManager events)
    {
        events.subscribe!Collision(this);
    }

    void update(EntityManager entities, EventManager events, double dt) { }

    void receive(E)(E event) pure nothrow if (is(E : Collision))
    {
        try
        {
            debug writefln("Entities collided: %s, %s", event.first.id, event.second.id);
        }
        catch (Throwable o)
        {
        }
    }
}
```

`<sidenote>`  
For those of you who've made it so far: should `pure nothrow` be enforced upon
the `receive` callback?  
`</sidenote>`

A few events are emitted by the **star-entity** library:
- `EntityCreatedEvent`
- `EntityDestroyedEvent`
- `ComponentAddedEvent(C)`
- `ComponentRemovedEvent(C)`

### Engine
The engine ties everything together. It allows you to perform everything listed
above, and manage your own game / input loop.

```c++
while (true)
{
    engine.update(0.02);
}
```

## License
This code is licensed under the MIT License. See LICENSE for the full text.
