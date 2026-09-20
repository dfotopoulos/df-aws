#!/usr/bin/env python3
"""
Utility script to convert an unencrypted PuTTY Private Key (.ppk v2) to
an OpenSSH/PEM format RSA Private Key (.pem) required by AWS EC2 for
Windows Administrator password decryption.
"""

import sys
import base64
import struct
import os

def encode_length(l):
    if l < 0x80:
        return bytes([l])
    s = []
    while l > 0:
        s.append(l & 0xff)
        l >>= 8
    s.reverse()
    return bytes([0x80 | len(s)]) + bytes(s)

def encode_integer(val):
    if val == 0:
        b = b'\x00'
    else:
        length = (val.bit_length() + 7) // 8
        b = val.to_bytes(length, byteorder='big')
        if b[0] & 0x80:
            b = b'\x00' + b
    return b'\x02' + encode_length(len(b)) + b

def encode_sequence(items):
    body = b''.join(items)
    return b'\x30' + encode_length(len(body)) + body

def read_str(b, offset):
    l = struct.unpack('>I', b[offset:offset+4])[0]
    return b[offset+4:offset+4+l], offset+4+l

def read_mpint(b, offset):
    data, offset = read_str(b, offset)
    return int.from_bytes(data, byteorder='big', signed=False), offset

def ppk_to_pem(ppk_path, pem_path=None):
    if not os.path.exists(ppk_path):
        print(f"Error: File not found: {ppk_path}")
        sys.exit(1)

    with open(ppk_path, 'r', encoding='utf-8', errors='ignore') as f:
        lines = [line.strip() for line in f]

    if not any('PuTTY-User-Key-File' in l for l in lines):
        print("Error: Not a valid PuTTY private key file.")
        sys.exit(1)

    # Check for encryption
    enc_line = next((l for l in lines if l.startswith('Encryption:')), '')
    if 'none' not in enc_line.lower():
        print(f"Error: {enc_line}. Passphrase protected PPK keys cannot be auto-converted.")
        sys.exit(1)

    pub_idx = lines.index(next(l for l in lines if l.startswith('Public-Lines:'))) + 1
    priv_idx = lines.index(next(l for l in lines if l.startswith('Private-Lines:'))) + 1
    mac_idx = lines.index(next(l for l in lines if l.startswith('Private-MAC:')))

    pub_b64 = ''.join(lines[pub_idx:priv_idx - 1])
    priv_b64 = ''.join(lines[priv_idx:mac_idx])

    pub_bytes = base64.b64decode(pub_b64)
    priv_bytes = base64.b64decode(priv_b64)

    algo, off = read_str(pub_bytes, 0)
    if algo != b'ssh-rsa':
        print(f"Error: Key algorithm is {algo.decode()}, but RSA (ssh-rsa) is required.")
        sys.exit(1)

    e, off = read_mpint(pub_bytes, off)
    n, off = read_mpint(pub_bytes, off)

    d, off = read_mpint(priv_bytes, 0)
    p, off = read_mpint(priv_bytes, off)
    q, off = read_mpint(priv_bytes, off)
    iqmp, off = read_mpint(priv_bytes, off)

    dmp1 = d % (p - 1)
    dmq1 = d % (q - 1)

    der = encode_sequence([
        encode_integer(0),
        encode_integer(n),
        encode_integer(e),
        encode_integer(d),
        encode_integer(p),
        encode_integer(q),
        encode_integer(dmp1),
        encode_integer(dmq1),
        encode_integer(iqmp),
    ])

    b64 = base64.b64encode(der).decode('ascii')
    pem_lines = [b64[i:i+64] for i in range(0, len(b64), 64)]
    pem_content = '-----BEGIN RSA PRIVATE KEY-----\n' + '\n'.join(pem_lines) + '\n-----END RSA PRIVATE KEY-----\n'

    if not pem_path:
        pem_path = os.path.splitext(ppk_path)[0] + '.pem'

    with open(pem_path, 'w', encoding='ascii') as f:
        f.write(pem_content)

    print(f"Successfully converted:\n  From: {ppk_path}\n  To:   {pem_path}")
    return pem_path

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python convert-ppk-to-pem.py <path-to-key.ppk> [path-to-output.pem]")
        sys.exit(1)
    ppk_to_pem(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else None)
