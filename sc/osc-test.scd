n = NetAddr("localhost", 56101);

n.sendMsg("/list");
n.sendMsg("/assets/list");
n.sendMsg("/commands/list");
n.sendMsg("/assets/list");

n.sendMsg("/load", "numbers");
n.sendMsg("/animations/list");