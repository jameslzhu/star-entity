///
/// Defines an architecture for event receiving and subscribing.
/// Events may be structs or components.
/// Event receivers must implement the Receiver(E) interface.
///
/// Copyright: Copyright (c) 2014 James Zhu.
///
/// License: MIT License (Expat). See accompanying file LICENSE.
///
/// Authors: James Zhu <github.com/jzhu98>
///

module star.entity.event;

import std.traits;

private interface BaseReceiver
{
}

template typename(C)
{
    alias typename = mangledName!C;
}

/// Recieves events of type E.
interface Receiver(E) : BaseReceiver
{
    /// Event callback for an event E.
    void receive(E event) pure nothrow;
}

/// Manages event subscription and emission.
class EventManager
{
public:
    /// Subscribe reciever to a certain event E.
    void subscribe(E)(Receiver!E receiver) pure nothrow @safe
    {
        auto name = typename!E;
        if (name in _receivers)
        {
            _receivers[name] ~= receiver;
        }
        else
        {
            _receivers[name] = [receiver];
        }
    }

    /// Notify all receivers of an event E. Calls their receive callback.
    void emit(E)(E event) pure nothrow @trusted
    {
        if (typename!E in _receivers)
        {
            foreach(r; _receivers[typename!E])
            {
                auto receiver = cast(Receiver!E) r;
                receiver.receive(event);
            }
        }
    }
private:
    BaseReceiver[][string] _receivers;
}

unittest
{
    struct Explosion { }

    class Block : Receiver!Explosion
    {
        bool destroyed = false;
        void receive(Explosion event)
        {
            destroyed = true;
        }
    }

    auto manager = new EventManager;
    auto block = new Block;
    assert(block.destroyed == false);

    manager.subscribe!Explosion(block);
    assert(manager._receivers.length == 1);
    assert(typename!Explosion in manager._receivers);
    assert(manager._receivers[typename!Explosion].length == 1);

    bool hasReceiver(E)(EventManager manager, Receiver!E receiver)
    {
        bool result = false;
        foreach(r; manager._receivers[typename!E])
        {
            if (r == receiver)
            {
                result = true;
            }
        }
        return result;
    }

    assert(hasReceiver!Explosion(manager, block));

    manager.emit(Explosion());
    assert(block.destroyed == true);
}
