#!/usr/bin/env python3
"""Exercise stage-1 RCV3 receiver. Uses only a public demonstration key.
Offline self-test validates fixtures; it does NOT test FPGA hardware.
"""
import argparse
from dataclasses import dataclass, replace
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import secrets
import struct
import time
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.exceptions import InvalidTag

KEY = bytes.fromhex('2B7E151628AED2A6ABF7158809CF4F3C')

@dataclass(frozen=True)
class Case:
    name: str
    header: bytes
    payload: bytes
    plaintext: bytes
    expect: str


def make_case(name, sequence, plaintext, width, height, kind='valid'):
    nonce = secrets.token_bytes(8)
    while nonce == bytes(8):
        nonce = secrets.token_bytes(8)
    iv = nonce + bytes(4)
    aad = struct.pack('>BBBBHHHHHH', 3, 1, 3, 1, width, height,
                      len(plaintext), 0, 1, sequence)
    enc_key = bytes([KEY[0] ^ 1]) + KEY[1:] if kind == 'wrong_key' else KEY
    sealed = AESGCM(enc_key).encrypt(iv, plaintext, aad)
    header = b'RCV3' + aad + iv
    expected = 'ACCEPT' if kind == 'valid' else 'REJECT'
    if kind.startswith('ciphertext_'):
        position = {'ciphertext_first': 0, 'ciphertext_middle': len(plaintext)//2,
                    'ciphertext_last': len(plaintext)-1}[kind]
        sealed = sealed[:position] + bytes([sealed[position] ^ 1]) + sealed[position+1:]
    elif kind == 'tag':
        sealed = sealed[:-1] + bytes([sealed[-1] ^ 1])
    elif kind == 'iv':
        header = header[:20] + bytes([header[20] ^ 1]) + header[21:]
    elif kind == 'aad':
        # Swapping unequal dimensions preserves byte length and structural validity.
        header = header[:8] + struct.pack('>HH', height, width) + header[12:]
    elif kind == 'malformed_length':
        header = header[:12] + b'\x00\x00' + header[14:]
        expected = 'HEADER_REJECT'
    elif kind not in ('valid', 'wrong_key'):
        raise ValueError(kind)
    return Case(name, header, sealed, plaintext, expected)


def make_suite(width=17, height=19):
    if width == height or not 1 <= width <= 512 or not 1 <= height <= 512:
        raise ValueError('Use unequal dimensions between 1 and 512.')
    size = width * height * 3
    if not 1 <= size <= 4096:
        raise ValueError('Stage-1 suite requires a single chunk (at most 4096 bytes).')
    plain = bytes((i*29 + 7) & 255 for i in range(size))
    kinds = ['valid', 'ciphertext_first', 'ciphertext_middle', 'ciphertext_last',
             'tag', 'iv', 'aad', 'wrong_key', 'malformed_length']
    cases = [make_case(k, 100+i, plain, width, height, k) for i, k in enumerate(kinds)]
    cases.append(replace(cases[0], name='replay_accepted_frame', expect='HEADER_REJECT'))
    cases.append(make_case('valid_after_rejections', 120, plain, width, height))
    return cases


def validate_fixtures(cases):
    for c in cases:
        assert len(c.header) == 32 and c.header[:4] == b'RCV3'
        if c.expect == 'HEADER_REJECT':
            continue
        try:
            plain = AESGCM(KEY).decrypt(c.header[20:32], c.payload, c.header[4:20])
        except InvalidTag:
            assert c.expect == 'REJECT', c.name
        else:
            assert c.expect == 'ACCEPT' and plain == c.plaintext, c.name


class Wire:
    def __init__(self, port, timeout, transcript):
        self.port, self.timeout, self.transcript = port, timeout, transcript

    def exact(self, count):
        stop = time.monotonic() + self.timeout
        data = bytearray()
        while len(data) < count:
            if time.monotonic() >= stop:
                raise TimeoutError(f'Timed out reading {count} bytes')
            part = self.port.read(count-len(data))
            if part:
                data.extend(part)
        return bytes(data)

    def line(self):
        stop = time.monotonic() + self.timeout
        data = bytearray()
        while time.monotonic() < stop:
            part = self.port.read(1)
            if not part:
                continue
            data.extend(part)
            if len(data) > 1024:
                raise ValueError('Unexpected binary data or overlong status line')
            if part == b'\n':
                text = bytes(data).decode('ascii', errors='strict').strip()
                if text:
                    self.transcript.append(text)
                    if text.startswith('RX_FATAL'):
                        raise RuntimeError(text)
                    return text
                data.clear()
        raise TimeoutError('Timed out waiting for receiver status')

    def until(self, prefix):
        # Bound line count as well as individual reads; unexpected data is a failure.
        for _ in range(100):
            line = self.line()
            if line.startswith(prefix):
                return line
        raise ValueError('Expected status not found: ' + prefix)

    def send(self, data):
        if self.port.write(data) != len(data):
            raise OSError('Incomplete UART write')
        self.port.flush()


def run_case(wire, c):
    start = len(wire.transcript)
    wire.send(c.header)
    line = wire.line()
    if line.startswith('RX_HEADER_REJECT '):
        if c.expect != 'HEADER_REJECT':
            raise AssertionError(c.name + ': unexpected header rejection: ' + line)
        wire.until('RX_READY_HEADER ')
        return {'name': c.name, 'result': 'HEADER_REJECT', 'pass': True,
                'observed_status': wire.transcript[start:]}
    if c.expect == 'HEADER_REJECT':
        raise AssertionError(c.name + ': invalid/replayed header was accepted')
    if line != f'RX_READY_CIPHERTEXT {len(c.plaintext)} TAG_BYTES 16':
        raise AssertionError('Unexpected receiver status: ' + line)
    wire.send(c.payload)
    recovered = None
    probe = cleanup = auth = False
    for _ in range(100):
        line = wire.line()
        if line == 'RX_AUTH_PROBE_UNCHANGED':
            probe = True
        elif line == 'RX_AUTH_ACCEPTED':
            auth = True
        elif line.startswith('RX_PLAINTEXT_BEGIN '):
            if c.expect != 'ACCEPT' or not auth or recovered is not None:
                raise AssertionError(c.name + ': unauthorized or duplicate UART release')
            n = int(line.split()[-1])
            if n != len(c.plaintext):
                raise AssertionError('Unexpected plaintext length')
            recovered = wire.exact(n)
            if wire.line() != 'RX_PLAINTEXT_END':
                raise AssertionError('Missing plaintext end marker')
        elif line == 'RX_BUFFERS_ZEROIZED':
            cleanup = True
        elif line.startswith('RX_TRANSACTION_DONE '):
            actual = line.split()[-1]
            if actual != c.expect or not probe or not cleanup:
                raise AssertionError(c.name + ': failed status/probe/cleanup checks')
            if c.expect == 'ACCEPT' and recovered != c.plaintext:
                raise AssertionError(c.name + ': recovery mismatch')
            if c.expect == 'REJECT' and recovered is not None:
                raise AssertionError(c.name + ': plaintext on rejection')
            wire.until('RX_READY_HEADER ')
            return {'name': c.name, 'result': actual, 'pass': True,
                    'uart_plaintext_bytes': 0 if recovered is None else len(recovered),
                    'header_hex': c.header.hex(),
                    'payload_sha256': hashlib.sha256(c.payload).hexdigest(),
                    'observed_status': wire.transcript[start:]}
    raise ValueError('Transaction did not complete')


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--self-test', action='store_true')
    p.add_argument('--port')
    p.add_argument('--baud', type=int, default=115200)
    p.add_argument('--width', type=int, default=17)
    p.add_argument('--height', type=int, default=19)
    p.add_argument('--timeout', type=float, default=120)
    p.add_argument('--output', type=Path, default=None)
    args = p.parse_args()
    cases = make_suite(args.width, args.height)
    validate_fixtures(cases)
    if args.self_test:
        print(f'OFFLINE FIXTURES PASS: {len(cases)} cases; FPGA not tested.')
        return 0
    if not args.port:
        p.error('--port is required for a board run')
    import serial
    output = args.output or Path('receiver_run_' + datetime.now().strftime('%Y%m%d_%H%M%S'))
    output.mkdir(parents=True, exist_ok=False)
    transcript, results = [], []
    report = {'stage': 'trusted_firmware_receiver_baseline',
              'started_utc': datetime.now(timezone.utc).isoformat(),
              'cases': results, 'overall_pass': False,
              'scope': 'UART output and firmware-reported probe/cleanup; no independent DDR bus monitor'}
    try:
        with serial.Serial(args.port, args.baud, timeout=0.25, write_timeout=10) as port:
            print('Port open. Now reset/relaunch the NEW receiver application in Vitis.')
            wire = Wire(port, args.timeout, transcript)
            wire.until('PCF_EXTERNAL_RECEIVER_STAGE1')
            wire.until('RX_READY_HEADER ')
            for c in cases:
                result = run_case(wire, c)
                results.append(result)
                print(c.name + ': PASS (' + result['result'] + ')')
            wire.send(b'END3' + bytes(28))
            wire.until('RX_SESSION_DONE ')
            report['overall_pass'] = len(results) == len(cases) and all(x['pass'] for x in results)
    except Exception as exc:
        report['error'] = str(exc)
        print('FAILED:', exc)
    finally:
        (output/'summary.json').write_text(json.dumps(report, indent=2))
        (output/'uart_transcript.txt').write_text('\n'.join(transcript)+'\n')
    print('BOARD OVERALL:', 'PASS' if report['overall_pass'] else 'FAIL')
    print('Evidence:', output.resolve())
    return 0 if report['overall_pass'] else 1

if __name__ == '__main__':
    raise SystemExit(main())
