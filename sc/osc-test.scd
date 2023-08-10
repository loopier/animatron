n = NetAddr("localhost", 56101);

n.sendMsg("/list");
n.sendMsg("/commands/list");
n.sendMsg("/assets/list");
n.sendMsg("/variables/list");

n.sendMsg("/load", "numbers");
n.sendMsg("/animations/list");
n.sendMsg("/actors/list");

n.sendMsg("/load", "mama");
n.sendMsg("/load", "numbers");
n.sendMsg("/create", "x", "mama");
n.sendMsg("/animation", "x", "numbers");
n.sendMsg("/animation", "x", "bla");

(
n.sendMsg("/load", "mama");
n.sendMsg("/load", "numbers");
n.sendMsg("/create", "x", "mama");
// n.sendMsg("/create", "n", "numbers");
)
n.sendMsg("/remove", "n");
n.sendMsg("/free", "x");
n.sendMsg("/scale", "x", 0.1, 0.5);
n.sendMsg("/scale", "x", 1);
n.sendMsg("/position", "x", 150, 50);
n.sendMsg("/position", "x", 550);
n.sendMsg("/bla", "x", 300, 200);
n.sendMsg("/animation", "x", "numbers");
n.sendMsg("/animation", "x", "mama");
n.sendMsg("/position/x", "x", 300);
n.sendMsg("/position/y", "x", 200);
n.sendMsg("/position", "x", 500);
n.sendMsg("/scale", "x", 1);
n.sendMsg("/scale/x", "x", 2);
n.sendMsg("/scale/y", "x", 3);
n.sendMsg("/apply/scale", "x", 2,2);
n.sendMsg("/rotation", "x", 180);
n.sendMsg("/rotation/degrees", "x", 90);
n.sendMsg("/stop", "x");
n.sendMsg("/play", "x");
n.sendMsg("/play/backwards", "x");
n.sendMsg("/reverse", "x");
n.sendMsg("/frame", "x", 0);
n.sendMsg("/frame", "x", 3);
n.sendMsg("/frame", "x", -1);
n.sendMsg("/frame/progress", "x", 0.1);
n.sendMsg("/flip/v", "x", 1);
n.sendMsg("/flip/h", "x", 1);
n.sendMsg("/speed/scale", "x", 2);
n.sendMsg("/speed", "x", 1);
n.sendMsg("/offset", "x", 0, 200);
n.sendMsg("/offset/y", "x", -200);
n.sendMsg("/offset/x", "x", -200);
n.sendMsg("/animation/loop", "x", 0);
n.sendMsg("/loop", "x", 1);
n.sendMsg("/play", "x");

(
n.sendMsg("/load", "mama");
// n.sendMsg("/create", "x", "mama");
)
n.sendMsg("/set", "/x", 2);
n.sendMsg("/def", "/red/mama", "argA", "argB", ",", "/create", "x", "mama", ",", "/speed", "x", "/x", ",", "/color", "x", 1, 0, 0);
n.sendMsg("/red/mama")
