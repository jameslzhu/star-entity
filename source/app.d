import std.stdio, std.container, std.math;

import star.component, star.entity;

class Test : Component
{
    int value = 10;
}

class Test2 : Component
{
    int val = 20;
}

int main(string[] args)
{
    auto manager = new EntityManager();

    auto entity = manager.create();

    entity.add(new Test());
    entity.add(new Test2());

    auto testComponent = entity.component!Test();
    auto testComponent2 = entity.component!Test2();

    writeln(testComponent.value);
    writeln(testComponent2.val);

    return 0;
}
