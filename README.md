*Zettings* is the simplest persistence layer I can think of. Its name is
a portmanteau of [Zig](https://github.com/ziglang/zig), the language I
used to implement it, and **settings**.

At its core, it maps (via POSIX `mmap`) a struct with fixed-length
members to a fixed-length file. It is intended to be used as the base
for a basic persistence layer for OPC/UA servers, i.e. a port of the
[XSettings project](https://github.com/ntd/xsettings) from the C world.

The demo program shows how this is supposed to work. It handles a set of
settings (boolean, numeric and string types) and allow to perform some
basic operations from command line.

```sh
# Show usage info
zig build run -- -h

# Create (-r) the schema file (demo.zettings) and dump (-d) its default values
zig build run -- -r -d demo.zettings

# Toggle all booleans (-t) and dump the new values
zig build run -- -t -d demo.zettings

# Now increment all numeric settings (-i) and dump the new values
zig build run -- -i -d demo.zettings

# Further dumps show that the last values are retained
zig build run -- -d demo.zettings

# Reset (-r) to the default values
zig build run -- -r -d demo.zettings
```
