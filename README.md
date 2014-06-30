star-entity
===========

An open-source entity-component-system, written in D.
**star-entity** offers component management, entity creation, event delivery,
and system management.

This framework is heavily based upon
[EntityX](github.com/alecthomas/entityx) by alecthomas and some ideas
from [Ashley](github.com/libgdx/ashley/).

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
[Evolve your Hierarchy](cowboyprogramming.com/2007/01/05/evolve-your-heirachy/)
offers a great introduction and overview of ECS frameworks and how they can
make your code more modular, more extensible, and simpler.

## Building
This project uses the DUB build system, found [here](code.dlang.org/download).

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

## License
This code is licensed under the MIT License. See LICENSE for the full text.
