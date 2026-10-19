"""Receive the length board self-test transcript; never transmit UART data."""
import argparse
import datetime
import json
from pathlib import Path
import re
import time

EXPECTED = [f"N_{n}_{kind}" for n in [1,15,16,17,4095,4096]
            for kind in ["VALID", "CIPHERTEXT_FIRST", "CIPHERTEXT_MIDDLE",
                         "CIPHERTEXT_LAST", "TAG", "VALID_AFTER_REJECTIONS"]]


def assess(lines):
    starts = [i for i, line in enumerate(lines)
              if line.strip() == "PCF_LENGTH_BOARD_TEST_START"]
    active = lines[starts[-1]:] if starts else []
    names = [line.split()[1] for line in active
             if line.startswith("LENGTH_TEST_PASS ")]
    signatures = [line.split()[1] for line in active
                  if re.fullmatch(r"GUARD_SIGNATURE [0-9a-fA-F]{8}", line)]
    signature_ok = bool(signatures) and int(signatures[0], 16) >> 16 == 0x5247
    failure = any(line.startswith(("LENGTH_TEST_FAIL", "LENGTH_FAILURE_STATE"))
                  or line.startswith("LENGTH_BOARD_OVERALL FAIL") for line in active)
    overall = (bool(starts) and len(starts) == 1 and signature_ok and names == EXPECTED
               and "LENGTH_BOARD_TESTS_PASSED 36 EXPECTED 36" in active
               and "LENGTH_BOARD_OVERALL PASS" in active and not failure)
    return {"stage": "release_guard_payload_length_board_tests",
            "overall_pass": overall, "passed_tests": names,
            "expected_tests": EXPECTED, "guard_signature_verified": signature_ok,
            "scope": "Firmware checks of guard/buffer/DMA status and a payload plus 64-byte DDR probe; no independent bus monitor."}


def self_test():
    lines = ["PCF_LENGTH_BOARD_TEST_START", "GUARD_SIGNATURE 52470000"]
    lines += ["LENGTH_TEST_PASS " + name for name in EXPECTED]
    lines += ["LENGTH_BOARD_TESTS_PASSED 36 EXPECTED 36", "LENGTH_BOARD_OVERALL PASS"]
    assert assess(lines)["overall_pass"]
    assert not assess(lines[:-1])["overall_pass"]
    assert not assess(lines + ["LENGTH_TEST_PASS N_1_VALID"])["overall_pass"]
    assert not assess([x.replace("36 EXPECTED", "35 EXPECTED") for x in lines])["overall_pass"]
    assert not assess([x.replace("52470000", "00000000") for x in lines])["overall_pass"]
    assert not assess(lines + ["LENGTH_TEST_FAIL N_1_TAG"])["overall_pass"]
    assert not assess(lines + lines)["overall_pass"]
    print("MONITOR SELF-TEST PASS: 7 cases; FPGA not tested.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port")
    parser.add_argument("--baud", type=int, default=115200)
    parser.add_argument("--timeout", type=float, default=120)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return 0
    if not args.port:
        parser.error("--port is required for the board run")
    import serial
    folder = args.output or Path("length_board_run_" + datetime.datetime.now().strftime("%Y%m%d_%H%M%S_%f"))
    folder.mkdir(parents=True, exist_ok=False)
    lines, error = [], None
    try:
        with serial.Serial(args.port, args.baud, timeout=0.2) as port:
            print("Port open. Now launch length_board_test_app in Vitis.", flush=True)
            deadline, pending, started = time.monotonic() + args.timeout, bytearray(), False
            with (folder / "uart_transcript.txt").open("w", encoding="utf-8") as transcript:
                while time.monotonic() < deadline:
                    pending.extend(port.read(port.in_waiting or 1))
                    while b"\n" in pending:
                        raw, _, rest = pending.partition(b"\n")
                        pending = bytearray(rest)
                        line = raw.decode("utf-8", errors="replace").strip("\r")
                        lines.append(line)
                        transcript.write(line + "\n")
                        transcript.flush()
                        print(line, flush=True)
                        started |= line == "PCF_LENGTH_BOARD_TEST_START"
                        if started and line.startswith("LENGTH_BOARD_OVERALL "):
                            return finish(folder, lines, None)
                if pending:
                    transcript.write(pending.decode("utf-8", errors="replace"))
            error = "Timed out waiting for the complete length board test result"
    except (serial.SerialException, OSError, KeyboardInterrupt) as exc:
        error = str(exc) or "Interrupted"
    return finish(folder, lines, error)


def finish(folder, lines, error):
    result = assess(lines)
    if error:
        result["error"] = error
        result["overall_pass"] = False
    (folder / "summary.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print("MONITOR OVERALL:", "PASS" if result["overall_pass"] else "FAIL")
    if error:
        print(error)
    print("Evidence:", folder.resolve())
    return 0 if result["overall_pass"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
