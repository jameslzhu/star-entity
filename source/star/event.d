module star.event;

private interface BaseReceiver
{
}

/// Recieves events of type E.
interface Receiver(E) : BaseReceiver
{
    void receive(E event);
}

/// Manages event subscription and emission.
class EventManager
{
public:
    /// Subscribe reciever to a certain event E.
    void subscribe(E)(Receiver!E receiver) pure nothrow @safe
    {
        auto classinfo = E.classinfo;
        if (classinfo in _receivers)
        {
            _receivers[classinfo] ~= receiver;
        }
        else
        {
            _receivers[classinfo] = [receiver];
        }
    }

    /// Notify all receivers of an event E. Calls their receive callback.
    void emit(E)(E event)
    {
        foreach(r; _receivers[event.classinfo])
        {
            auto receiver = cast(Receiver!E) r;
            receiver.receive(event);
        }
    }
private:
    BaseReceiver[][ClassInfo] _receivers;
}

unittest
{
    class Explosion { }

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
    assert(Explosion.classinfo in manager._receivers);
    assert(manager._receivers[Explosion.classinfo].length == 1);

    bool hasReceiver(E)(EventManager manager, Receiver!E receiver)
    {
        bool result = false;
        foreach(r; manager._receivers[E.classinfo])
        {
            if (r == receiver)
            {
                result = true;
            }
        }
        return result;
    }

    assert(hasReceiver!Explosion(manager, block));

    manager.emit(new Explosion);
    assert(block.destroyed == true);
}
