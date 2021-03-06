import std.stdio;
import std.socket;
import std.exception;
import std.file;
import std.conv;

import message_struct;
import msgpack;

int main(string[] args)
{
    enforce(args.length == 3);
    TcpSocket c = new TcpSocket;
    c.connect(new InternetAddress("localhost", 11344));

    Request!(MessageType.OUTLINE) req;
    req.src = readText(args[1]);
    //req.cursor = to!uint(args[2]);
    auto bytes = msgpack.pack(req);
    uint[] len = [cast(uint)bytes.length];
    ubyte[] header = [1, MessageType.OUTLINE];
    len[0] += cast(uint)(2);
    writeln("Length: ", len);
    c.send(len);
    c.send(header);
    c.send(bytes);

    ubyte[] inbuffer;
    inbuffer.length = 1024;
    void receive(Socket s)
    {
        enum MAX_MESSAGE_SIZE = 64 * 1024 * 1024;
        uint length = uint.max;
        ptrdiff_t offset = 0;
        do {
            ptrdiff_t rc = s.receive(inbuffer[offset..$]);
            enforce(rc != Socket.ERROR, "socket error");
            enforce(rc != 0, "client closed connection");
            offset += rc;
            if (length == length.max && offset >= length.sizeof) {
                (cast(ubyte*) &length)[0..length.sizeof] = inbuffer[0..length.sizeof];
                enforce(length < MAX_MESSAGE_SIZE, "message buffer overflow");
                length += length.sizeof;
                inbuffer.length = length;
            }
        } while (offset < length);
    }
    receive(c);
    alias Rep = Reply!(MessageType.OUTLINE);
    auto rep = msgpack.unpack!Rep(inbuffer[uint.sizeof + 2 * ubyte.sizeof..$]);
    writeln(rep);
    
    return 0;
}
