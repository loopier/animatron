n = NetAddr("localhost", 56101);

n.sendMsg("/list");
n.sendMsg("/commands/list");
n.sendMsg("/assets/list");

n.sendMsg("/load", "numbers");
n.sendMsg("/animations/list");

n.sendMsg("/load", "mama");
n.sendMsg("/load", "numbers");
n.sendMsg("/create", "x", "mama");
n.sendMsg("/animation", "x", "numbers");
n.sendMsg("/animation", "x", "bla");

(
n.sendMsg("/load", "mama");
n.sendMsg("/load", "numbers");
n.sendMsg("/create", "x", "mama");
)
n.sendMsg("/scale", "x", 0.1, 0.5);
n.sendMsg("/scale", "x", 1);
n.sendMsg("/position", "x", 150, 50);
n.sendMsg("/bla", "x", 300, 200);
n.sendMsg("/animation", "x", "numbers");
n.sendMsg("/animation", "x", "mama");
n.sendMsg("/position/x", "x", 300);
n.sendMsg("/position/y", "x", 200);
n.sendMsg("/position", "x", 500);
n.sendMsg("/scale/x", "x", 1);
n.sendMsg("/scale/y", "x", 1);