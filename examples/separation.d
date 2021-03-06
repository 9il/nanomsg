/*
    Copyright (c) 2013 Martin Sustrik  All rights reserved.
    Copyright (c) 2013 GoPivotal, Inc.  All rights reserved.

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
import deimos.nanomsg.pipeline;
import deimos.nanomsg.inproc;
import deimos.nanomsg.ipc;
import deimos.nanomsg.tcp;
import testutil;

import core.stdc.errno;

enum SOCKET_ADDRESS_INPROC = "inproc://a";
enum SOCKET_ADDRESS_IPC = "ipc://test-separation.ipc";
enum SOCKET_ADDRESS_TCP = "tcp://127.0.0.1:5556";

/*  This test checks whether the library prevents interconnecting sockets
    between different non-compatible protocols. */

int main ()
{
    int rc;
    int pair;
    int pull;
    int timeo;

    /*  Inproc: Bind first, connect second. */
    pair = test_socket (AF_SP, NN_PAIR);
    test_bind (pair, SOCKET_ADDRESS_INPROC);
    pull = test_socket (AF_SP, NN_PULL);
    test_connect (pull, SOCKET_ADDRESS_INPROC);
    timeo = 100;
    test_setsockopt (pair, NN_SOL_SOCKET, NN_SNDTIMEO,
        &timeo, timeo.sizeof);
    enum msg = "ABC";
    rc = nn_send (pair, msg.ptr, 3, 0);
    assert (rc < 0 && nn_errno () == ETIMEDOUT);
    test_close (pull);
    test_close (pair);

    /*  Inproc: Connect first, bind second. */
    pull = test_socket (AF_SP, NN_PULL);
    test_connect (pull, SOCKET_ADDRESS_INPROC);
    pair = test_socket (AF_SP, NN_PAIR);
    test_bind (pair, SOCKET_ADDRESS_INPROC);
    timeo = 100;
    test_setsockopt (pair, NN_SOL_SOCKET, NN_SNDTIMEO,
        &timeo, timeo.sizeof);
    rc = nn_send (pair, msg.ptr, 3, 0);
    assert (rc < 0 && nn_errno () == ETIMEDOUT);
    test_close (pull);
    test_close (pair);



    /*  IPC */
    pair = test_socket (AF_SP, NN_PAIR);
    test_bind (pair, SOCKET_ADDRESS_IPC);
    pull = test_socket (AF_SP, NN_PULL);
    test_connect (pull, SOCKET_ADDRESS_IPC);
    timeo = 100;
    test_setsockopt (pair, NN_SOL_SOCKET, NN_SNDTIMEO,
        &timeo, timeo.sizeof);
    rc = nn_send (pair, msg.ptr, 3, 0);
    assert (rc < 0 && nn_errno () == ETIMEDOUT);
    test_close (pull);
    test_close (pair);



    /*  TCP */
    pair = test_socket (AF_SP, NN_PAIR);
    test_bind (pair, SOCKET_ADDRESS_TCP);
    pull = test_socket (AF_SP, NN_PULL);
    test_connect (pull, SOCKET_ADDRESS_TCP);
    timeo = 100;
    test_setsockopt (pair, NN_SOL_SOCKET, NN_SNDTIMEO,
        &timeo, timeo.sizeof);
    rc = nn_send (pair, msg.ptr, 3, 0);
    assert (rc < 0 && nn_errno () == ETIMEDOUT);
    test_close (pull);
    test_close (pair);

    return 0;
}

