#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Slavi Pantaleev
#
# SPDX-License-Identifier: AGPL-3.0-or-later

"""Uploads a small payload to Send over its WebSocket API (`/api/ws`).

Send's browser client encrypts payloads client-side, but the server treats the
uploaded bytes as opaque, so a plain (unencrypted) payload exercises the very
same server-side code path: metadata is written to Redis and the blob is
written to the storage backend.

Implemented against the Python standard library only, so that no extra
packages need to be installed on the machine under test.

Prints a single JSON object describing the upload to standard output.
"""

import base64
import json
import os
import socket
import struct
import sys


def ws_handshake(sock, host_header, path):
    key = base64.b64encode(os.urandom(16)).decode('ascii')
    request = (
        'GET {path} HTTP/1.1\r\n'
        'Host: {host}\r\n'
        'Upgrade: websocket\r\n'
        'Connection: Upgrade\r\n'
        'Sec-WebSocket-Key: {key}\r\n'
        'Sec-WebSocket-Version: 13\r\n'
        '\r\n'
    ).format(path=path, host=host_header, key=key)
    sock.sendall(request.encode('ascii'))

    buf = b''
    while b'\r\n\r\n' not in buf:
        chunk = sock.recv(4096)
        if not chunk:
            raise RuntimeError('connection closed during WebSocket handshake')
        buf += chunk

    head, rest = buf.split(b'\r\n\r\n', 1)
    status_line = head.split(b'\r\n', 1)[0].decode('latin-1')
    if '101' not in status_line:
        raise RuntimeError('WebSocket handshake failed: %s' % status_line)
    return rest


def ws_send(sock, payload, opcode):
    header = bytearray()
    header.append(0x80 | opcode)
    length = len(payload)
    if length < 126:
        header.append(0x80 | length)
    elif length < (1 << 16):
        header.append(0x80 | 126)
        header += struct.pack('!H', length)
    else:
        header.append(0x80 | 127)
        header += struct.pack('!Q', length)
    mask = os.urandom(4)
    header += mask
    masked = bytearray(payload)
    for i in range(length):
        masked[i] ^= mask[i % 4]
    sock.sendall(bytes(header) + bytes(masked))


class Reader(object):
    def __init__(self, sock, buffered=b''):
        self.sock = sock
        self.buf = bytearray(buffered)

    def need(self, count):
        while len(self.buf) < count:
            chunk = self.sock.recv(4096)
            if not chunk:
                raise RuntimeError('connection closed while reading frame')
            self.buf += chunk
        out = bytes(self.buf[:count])
        del self.buf[:count]
        return out

    def frame(self):
        while True:
            first, second = self.need(2)
            opcode = first & 0x0F
            masked = bool(second & 0x80)
            length = second & 0x7F
            if length == 126:
                length = struct.unpack('!H', self.need(2))[0]
            elif length == 127:
                length = struct.unpack('!Q', self.need(8))[0]
            mask = self.need(4) if masked else None
            data = bytearray(self.need(length))
            if mask:
                for i in range(len(data)):
                    data[i] ^= mask[i % 4]
            if opcode in (0x1, 0x2):
                return bytes(data)
            if opcode == 0x8:
                raise RuntimeError('server closed the WebSocket connection')
            # Ignore ping/pong/continuation frames.


def main():
    host = sys.argv[1]
    port = int(sys.argv[2])
    payload = sys.argv[3].encode('utf-8') if len(sys.argv) > 3 else b'send-molecule-payload'

    sock = socket.create_connection((host, port), timeout=60)
    sock.settimeout(60)
    try:
        rest = ws_handshake(sock, '%s:%d' % (host, port), '/api/ws')
        reader = Reader(sock, rest)

        header = {
            'fileMetadata': base64.b64encode(b'molecule-metadata').decode('ascii'),
            'authorization': 'send-v1 ' + base64.b64encode(b'molecule-auth').decode('ascii'),
            'timeLimit': 3600,
            'dlimit': 1,
        }
        ws_send(sock, json.dumps(header).encode('utf-8'), 0x1)
        created = json.loads(reader.frame().decode('utf-8'))
        if 'id' not in created:
            raise RuntimeError('Send refused the upload: %s' % json.dumps(created))

        ws_send(sock, payload, 0x2)
        # A single NUL byte is Send's end-of-file marker.
        ws_send(sock, b'\x00', 0x2)

        finished = json.loads(reader.frame().decode('utf-8'))
        if not finished.get('ok'):
            raise RuntimeError('Send did not acknowledge the upload: %s' % json.dumps(finished))
    finally:
        sock.close()

    print(json.dumps({
        'id': created['id'],
        'owner_token': created['ownerToken'],
        'url': created['url'],
        'payload_size': len(payload),
    }))


if __name__ == '__main__':
    main()
