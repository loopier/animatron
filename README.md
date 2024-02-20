# Animatron

**Animatron** is an experimental environment (very much "work in
progress") that enables creation of "visual poetry," in the form of
animations and images, created in real-time through live coding.  It
implemented using the open-source [Godot
engine](https://godotengine.org/), and communicates with any "client"
application or live coding language &mdash; such as
[SuperCollider](https://supercollider.github.io/) &mdash; via the
network, using the Open Sound Control (OSC) protocol.

Trying to build a pseudo live coding language using OSC (OCL - Open Control Language?).

# Installation

1. Download the latest version for your platform from the [release page](https://github.com/loopier/animatron/releases).
2. Run the executable.

To use Animatron you'll need some animations to work with.

Animations are just collections of `.png` files or spritesheets (like the ones used in videogames).

When using image collections, it gathers them from named folders, using the folder name as the animation identifier.

The default directory to store animations is: `user://assets/animations` where `user://` depends on the system you're on:

- Linux`~/.local/share/animatron/`
- macOS`~/Library/Application Support/`
- Windows`%APPDATA%\`

For example, on Linux, having a collection of `.png` images in this directory `~/.local/share/animatron/assets/animations/whatever/` would allow us to create an actor with:

```
/load whatever
/create myactor whatever
```

This works with symlinks as well (shortcuts), so you don't need to have the actual folders in that path.

If you want to use images that are in other directories, you'll can change the assets path:

``` animatron
/assets/path path/to/your/custom/directory
```

We stronglyl recommend using your own animations, but if you need something to start you can find some in [this link](https://my.hidrive.com/share/jzod7tz1uq).

# Versions

This repo is a remake of [Animatron](https://github.com/loopier/animatron-godot3) for Godot 4.x and above. Some stuff might be unstable.
