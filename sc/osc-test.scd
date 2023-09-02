(
n = NetAddr("localhost", 56101);
OSCdef(\status, { arg args, time, srcAddr, port; args[1..].first.postln; }, "/status/reply");
OSCdef(\error, { arg args, time, srcAddr, port; args[1..].first.postln; }, "/error/reply");
)

n.sendMsg("/list");
n.sendMsg("/commands/list");
n.sendMsg("/assets/list");
n.sendMsg("/assets");
n.sendMsg("/variables/list");

n.sendMsg("/load", "numbers");
n.sendMsg("/load", "canon-man");
n.sendMsg("/load", "om-walk-e");
n.sendMsg("/load", "fox-walk");
n.sendMsg("/load", "mama");
n.sendMsg("/animations/list");
n.sendMsg("/animations");
n.sendMsg("/actors/list");

n.sendMsg("/load", "mama");
n.sendMsg("/load", "numbers");
n.sendMsg("/create", "x", "fox-walk");
n.sendMsg("/create", "x", "om-walk-e");
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
n.sendMsg("/position", "x", 400, 500);
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
n.sendMsg("/hide", "x");
n.sendMsg("/show", "x");

(
n.sendMsg("/load", "mama");
n.sendMsg("/create", "x", "mama");
)
n.sendMsg("/set", "/x", 2);
n.sendMsg("/def", "/red/mama", "argA", "argB", ",", "/create", "x", "mama", ",", "/speed", "x", "/x", ",", "/color", "x", 1, 0, 0);
n.sendMsg("/def", "/ma/left", ",", "/position/x", "x", 0.2);
n.sendMsg("/def", "/ma/right", ",", "/position/x", "x", 0.7);
n.sendMsg("/red/mama")
n.sendMsg("/ma/left")
n.sendMsg("/ma/right")
n.sendMsg("/position/x", "x", 0.7)
n.sendMsg("/position/x", "x", 0.25)

// def
n.sendMsg("/commands/list")
n.sendMsg("/assets/list")
n.sendMsg("/load", "mama");
n.sendMsg("/def", "/ma", "actor", "anim", "scale", ",", "/create", "$actor", "$anim", ",", "/scale", "$actor", "$scale", "$scale");
n.sendMsg("/ma", "alo", "mama", 0.5);
n.sendMsg("/position/x", "alo", 0.2);
n.sendMsg("/ma", "ola", "mama", 0.5);
n.sendMsg("/list")
n.sendMsg("/free", "*");

// routine
n.sendMsg("/routine", "routineA", "inf", 1.0, "/cmdA", "argA", 2.3);
n.sendMsg("/routine", "routineA", 4, 0.5, "/cmdA", "argA", 1.3);
n.sendMsg("/routine", "routineA", "bla", 0.5, "/cmdA", "argA", 2.3);
n.sendMsg("/routines")
(
n.sendMsg("/load", "mama");
n.sendMsg("/create", "x", "mama");
n.sendMsg("/routine", "flipa", "inf", 0.25, "/flip/h", "x");
n.sendMsg("/routine", "flipe", "inf", 1, "/flip/v", "x");
)
n.sendMsg("/routine/free", "flip*")
n.sendMsg("/routines");
n.sendMsg("/routine", "flipa", 3, 0.5, "/flip/v", "x");

// toggle property
(
n.sendMsg("/load", "mama");
n.sendMsg("/create", "x", "mama");
)
// animation property
n.sendMsg("/flip/v", "x");
// actor propertyArray
n.sendMsg("/visible", "x");

// state machines
(
n.sendMsg("/load", "mama");
n.sendMsg("/create", "x", "mama");
n.sendMsg("/def", "/stateA1", ",", "/position/x", "x", 200);
n.sendMsg("/def", "/stateA2", ",", "/position/x", "x", 500);
n.sendMsg("/def", "/stateA3", ",", "/position/x", "x", 700);
n.sendMsg("/state", "machineA", "/stateA1", "/stateA2");
n.sendMsg("/state", "machineA", "/stateA2", "/stateA1", "/stateA3");
n.sendMsg("/state", "machineA", "/stateA3", "/stateA1", "/stateA3", "/stateA2");
n.sendMsg("/state", "machineB", "/stateB1", "/stateB1", "/stateB2");
n.sendMsg("/state", "machineB", "/stateB2", "/stateB2", "/stateB1");
n.sendMsg("/states");
)
n.sendMsg("/state/free", "machineB", "stateB1");
n.sendMsg("/state/free", "machineB", "stateB2");
n.sendMsg("/state/free", "machineA", "stateA3");
n.sendMsg("/state/free", "machine*", "s*");

n.sendMsg("/state/next", "machineA");
n.sendMsg("/state/next", "machine*");
n.sendMsg("/position/x", "x", 500);
n.sendMsg("/stateA2");
n.sendMsg("/commands/list");
n.sendMsg("/commands");

// post
n.sendMsg("/post", "alo\n", "bla bla bla");

// log
n.sendMsg("/log/level", "fatal");
n.sendMsg("/log/level", "error");
n.sendMsg("/log/level", "warn");
n.sendMsg("/log/level", "info");
n.sendMsg("/log/level", "debug");
n.sendMsg("/log/level", "verbose");

// relative property values
(
n.sendMsg("/load", "mama");
n.sendMsg("/create", "x", "mama");
n.sendMsg("/relative", "/scale", "x", 0.5);
)
