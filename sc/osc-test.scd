n = NetAddr("localhost", 56101);

n.sendMsg("/list");
n.sendMsg("/assets/list");
n.sendMsg("/commands/list");
n.sendMsg("/assets/list");

n.sendMsg("/load", "numbers");
n.sendMsg("/animations/list");

n.sendMsg("/load", "mama");
n.sendMsg("/load", "numbers");
n.sendMsg("/create", "x", "mama");
n.sendMsg("/animation", "x", "numbers");
n.sendMsg("/animation", "x", "bla");