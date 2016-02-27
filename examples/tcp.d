/*
    Copyright (c) 2012 Martin Sustrik  All rights reserved.
    Copyright 2015 Garrett D'Amore <garrett@damore.org>

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"),
    to deal in the Software without restriction, including without limitation
    the rights to use, copy, modify, merge, publish, distribute, sublicense,
    and/or sell copies of the Software, and to permit persons to whom
    the Software is furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included
    in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
    THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
    FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
    IN THE SOFTWARE.
*/



import deimos.nanomsg.nn;
import deimos.nanomsg.pair;
import deimos.nanomsg.pubsub;
import deimos.nanomsg.tcp;

import core.thread;
import core.time;
import core.stdc.errno;

import testutil;

/*  Tests TCP transport. */

enum SOCKET_ADDRESS = "tcp://127.0.0.1:5555";

__gshared int sc;

int main ()
{
    int rc;
    int sb;
    int i;
    int opt;
    size_t sz;
    int s1, s2;
    void * dummy_buf;

    /*  Try closing bound but unconnected socket. */
    sb = test_socket (AF_SP, NN_PAIR);
    test_bind (sb, SOCKET_ADDRESS);
    test_close (sb);

    /*  Try closing a TCP socket while it not connected. At the same time
        test specifying the local address for the connection. */
    sc = test_socket (AF_SP, NN_PAIR);
    test_connect (sc, "tcp://127.0.0.1;127.0.0.1:5555");
    test_close (sc);

    /*  Open the socket anew. */
    sc = test_socket (AF_SP, NN_PAIR);

    /*  Check NODELAY socket option. */
    sz = opt.sizeof;
    rc = nn_getsockopt (sc, NN_TCP, NN_TCP_NODELAY, &opt, &sz);
    assert (rc == 0);
    assert (sz == opt.sizeof);
    assert (opt == 0);
    opt = 2;
    rc = nn_setsockopt (sc, NN_TCP, NN_TCP_NODELAY, &opt, opt.sizeof);
    assert (rc < 0 && nn_errno () == EINVAL);
    opt = 1;
    rc = nn_setsockopt (sc, NN_TCP, NN_TCP_NODELAY, &opt, opt.sizeof);
    assert (rc == 0);
    sz = opt.sizeof;
    rc = nn_getsockopt (sc, NN_TCP, NN_TCP_NODELAY, &opt, &sz);
    assert (rc == 0);
    assert (sz == opt.sizeof);
    assert (opt == 1);

    /*  Try using invalid address strings. */
    rc = nn_connect (sc, "tcp://*:");
    assert (rc < 0);
    assert (nn_errno () == EINVAL);
    rc = nn_connect (sc, "tcp://*:1000000");
    assert (rc < 0);
    assert (nn_errno () == EINVAL);
    rc = nn_connect (sc, "tcp://*:some_port");
    assert (rc < 0);
    rc = nn_connect (sc, "tcp://eth10000;127.0.0.1:5555");
    assert (rc < 0);
    assert (nn_errno () == ENODEV);
    rc = nn_connect (sc, "tcp://127.0.0.1");
    assert (rc < 0);
    assert (nn_errno () == EINVAL);
    rc = nn_bind (sc, "tcp://127.0.0.1:");
    assert (rc < 0);
    assert (nn_errno () == EINVAL);
    rc = nn_bind (sc, "tcp://127.0.0.1:1000000");
    assert (rc < 0);
    assert (nn_errno () == EINVAL);
    rc = nn_bind (sc, "tcp://eth10000:5555");
    assert (rc < 0);
    assert (nn_errno () == ENODEV);
    rc = nn_connect (sc, "tcp://:5555");
    assert (rc < 0);
    assert (nn_errno () == EINVAL);
    rc = nn_connect (sc, "tcp://-hostname:5555");
    assert (rc < 0);
    assert (nn_errno () == EINVAL);
    rc = nn_connect (sc, "tcp://abc.123.---.#:5555");
    assert (rc < 0);
    assert (nn_errno () == EINVAL);
    rc = nn_connect (sc, "tcp://[::1]:5555");
    assert (rc < 0);
    assert (nn_errno () == EINVAL);
    rc = nn_connect (sc, "tcp://abc.123.:5555");
    assert (rc < 0);
    assert (nn_errno () == EINVAL);
    rc = nn_connect (sc, "tcp://abc...123:5555");
    assert (rc < 0);
    assert (nn_errno () == EINVAL);
    rc = nn_connect (sc, "tcp://.123:5555");
    assert (rc < 0);
    assert (nn_errno () == EINVAL);

    /*  Connect correctly. Do so before binding the peer socket. */
    test_connect (sc, SOCKET_ADDRESS);

    /*  Leave enough time for at least on re-connect attempt. */
    Thread.sleep (200.msecs);

    sb = test_socket (AF_SP, NN_PAIR);
    test_bind (sb, SOCKET_ADDRESS);

    /*  Ping-pong test. */
    for (i = 0; i != 100; ++i) {

        test_send (sc, "ABC");
        test_recv (sb, "ABC");

        test_send (sb, "DEF");
        test_recv (sc, "DEF");
    }

    /*  Batch transfer test. */
    for (i = 0; i != 100; ++i) {
        test_send (sc, "0123456789012345678901234567890123456789");
    }
    for (i = 0; i != 100; ++i) {
        test_recv (sb, "0123456789012345678901234567890123456789");
    }

    test_close (sc);
    test_close (sb);

    /*  Test whether connection rejection is handled decently. */
    sb = test_socket (AF_SP, NN_PAIR);
    test_bind (sb, SOCKET_ADDRESS);
    s1 = test_socket (AF_SP, NN_PAIR);
    test_connect (s1, SOCKET_ADDRESS);
    s2 = test_socket (AF_SP, NN_PAIR);
    test_connect (s2, SOCKET_ADDRESS);
    Thread.sleep (100.msecs);
    test_close (s2);
    test_close (s1);
    test_close (sb);

    /*  Test two sockets binding to the same address. */
    sb = test_socket (AF_SP, NN_PAIR);
    test_bind (sb, SOCKET_ADDRESS);
    s1 = test_socket (AF_SP, NN_PAIR);
    test_bind (s1, SOCKET_ADDRESS);
    sc = test_socket (AF_SP, NN_PAIR);
    test_connect (sc, SOCKET_ADDRESS);
    Thread.sleep (100.msecs);
    test_send (sb, "ABC");
    test_recv (sc, "ABC");
    test_close (sb);
    test_send (s1, "ABC");
    test_recv (sc, "ABC");
    test_close (sc);
    test_close (s1);

    /*  Test NN_RCVMAXSIZE limit */
    sb = test_socket (AF_SP, NN_PAIR);
    test_bind (sb, SOCKET_ADDRESS);
    s1 = test_socket (AF_SP, NN_PAIR);
    test_connect (s1, SOCKET_ADDRESS);
    opt = 4;
    rc = nn_setsockopt (sb, NN_SOL_SOCKET, NN_RCVMAXSIZE, &opt, opt.sizeof);
    assert (rc == 0);
    Thread.sleep (100.msecs);
    test_send (s1, "ABC");
    test_recv (sb, "ABC");
    test_send (s1, "0123456789012345678901234567890123456789");
    rc = nn_recv (sb, &dummy_buf, NN_MSG, NN_DONTWAIT);
    assert (rc < 0);
    assert (nn_errno () == EAGAIN);
    test_close (sb);
    test_close (s1);

    /*  Test that NN_RCVMAXSIZE can be -1, but not lower */
    sb = test_socket (AF_SP, NN_PAIR);
    opt = -1;
    rc = nn_setsockopt (sb, NN_SOL_SOCKET, NN_RCVMAXSIZE, &opt, opt.sizeof);
    assert (rc >= 0);
    opt = -2;
    rc = nn_setsockopt (sb, NN_SOL_SOCKET, NN_RCVMAXSIZE, &opt, opt.sizeof);
    assert (rc < 0);
    assert (nn_errno () == EINVAL);
    test_close (sb);

    /*  Test closing a socket that is waiting to bind. */
    sb = test_socket (AF_SP, NN_PAIR);
    test_bind (sb, SOCKET_ADDRESS);
    Thread.sleep (100.msecs);
    s1 = test_socket (AF_SP, NN_PAIR);
    test_bind (s1, SOCKET_ADDRESS);
    sc = test_socket (AF_SP, NN_PAIR);
    test_connect (sc, SOCKET_ADDRESS);
    Thread.sleep (100.msecs);
    test_send (sb, "ABC");
    test_recv (sc, "ABC");
    test_close (s1);
    test_send (sb, "ABC");
    test_recv (sc, "ABC");
    test_close (sb);
    test_close (sc);

    return 0;
}