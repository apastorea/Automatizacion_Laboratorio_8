#!/usr/bin/env python3
"""Captura sincronizada PSoC Lab8 + Rigol DS1202Z-E.

No programa el PSoC ni modifica el firmware. Escucha el anuncio de arranque
de Lab8, arma una adquisición única del Rigol y archiva UART, formas de onda,
captura de pantalla y metadatos. El modo predeterminado es MONITOR.
"""

from __future__ import annotations

import argparse
import csv
import io
import re
import sys
import time
from datetime import datetime
from pathlib import Path

import numpy as np
import serial


LAB8_ROOT = Path(__file__).resolve().parents[1]
TOOLS_DIR = LAB8_ROOT.parent / "Herramientas_Comunes" / "Rigol_y_UART"
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from rigol_ds1202ze import (  # noqa: E402
    acquire_screen_waveform,
    connect,
    save_json,
    save_screenshot,
    save_waveform_csv,
)


UART_FIELDS = (
    "k", "t_us", "adc_counts", "adc_mV", "y_cal_mV", "y_rel_mV",
    "r_mV", "u_solicitada_mV", "u_nominal_mV", "xhat1_mV",
    "xhat2_mV", "xi_mV", "innovacion_mV", "dac_pos", "dac_neg",
    "cpu_us", "intervalo_us", "flags",
)
EXPECTED_ROWS = 600


def configure_scope(scope, args):
    """Configure one acquisition without changing vertical positions."""
    scope.write(":STOP")
    for channel, scale in (("CHAN1", args.scale_ch1),
                           ("CHAN2", args.scale_ch2)):
        scope.write(f":{channel}:DISP ON")
        scope.write(f":{channel}:COUP DC")
        scope.write(f":{channel}:PROB 10")
        scope.write(f":{channel}:BWL 20M")
        scope.write(f":{channel}:SCAL {scale:.9g}")
    scope.write(":ACQ:TYPE HRES")
    scope.write(":TIM:MODE MAIN")
    scope.write(f":TIM:SCAL {args.time_scale:.9g}")
    scope.write(":TIM:OFFS 0")
    scope.write(":TRIG:MODE EDGE")
    scope.write(":TRIG:EDGE:SOUR CHAN1")
    scope.write(":TRIG:EDGE:SLOP POS")
    scope.write(f":TRIG:EDGE:LEV {args.trigger_level:.9g}")
    scope.write(":TRIG:SWE NORM")


def read_uart_and_arm(uart, scope, args):
    """Use the Lab8 startup banner as the capture clock."""
    received = bytearray()
    pending = bytearray()
    announced_at = None
    armed = False
    finished = False
    detected_mode = None
    detected_design = None
    rearm_checked = False
    force_checked = False
    forced_trigger = False
    state_before_force = None
    trigger_force_s = None
    deadline = time.monotonic() + args.timeout
    print("LISTO: UART y Rigol preparados. Presioná SW3/RESET una vez.",
          flush=True)

    while time.monotonic() < deadline:
        waiting = uart.in_waiting
        if waiting:
            block = uart.read(min(waiting, 16384))
            received.extend(block)
            pending.extend(block)
            if len(received) > 500_000:
                raise RuntimeError("UART superó 500 kB: protocolo inesperado")
            while b"\n" in pending:
                raw_line, _, rest = pending.partition(b"\n")
                pending = bytearray(rest)
                line = raw_line.decode("ascii", errors="replace").strip()
                if line.startswith("# LAB8 inicio;"):
                    announced_at = time.monotonic()
                    armed = False
                    rearm_checked = False
                    force_checked = False
                    forced_trigger = False
                    print("PSoC: anuncio LAB8 detectado.", flush=True)
                elif line.startswith("# LAB8 control_integral"):
                    match = re.search(r"\bmodo=([A-Z_]+)", line)
                    if match:
                        detected_mode = match.group(1)
                        print(f"PSoC: modo={detected_mode}", flush=True)
                elif line.startswith("# LAB8 diseno="):
                    match = re.search(r"\bdiseno=([A-Z_]+)", line)
                    if match:
                        detected_design = match.group(1)
                        print(f"PSoC: diseño={detected_design}", flush=True)
                elif line.startswith("# LAB8 END;"):
                    finished = True
                    break

        if announced_at is not None:
            elapsed = time.monotonic() - announced_at
            if not armed and elapsed >= args.arm_delay:
                scope.write(":SING")
                armed = True
                print(f"RIGOL ARMADO a t={elapsed:.3f} s.", flush=True)
            if armed and not rearm_checked and elapsed >= args.rearm_time:
                state = scope.query(":TRIG:STAT?").strip().upper()
                rearm_checked = True
                if state in ("STOP", "TD"):
                    scope.write(":SING")
                    print("RIGOL REARMADO: disparo anterior a la ventana.",
                          flush=True)
            if armed and not force_checked and elapsed >= args.force_time:
                state_before_force = scope.query(":TRIG:STAT?").strip().upper()
                force_checked = True
                if state_before_force in ("WAIT", "RUN", "AUTO"):
                    scope.write(":TFOR")
                    forced_trigger = True
                    trigger_force_s = time.monotonic() - announced_at
                    print(f"RIGOL: TFOR a t={trigger_force_s:.3f} s.",
                          flush=True)
                else:
                    print(f"RIGOL: adquisición ya detenida ({state_before_force}).",
                          flush=True)
        if finished:
            break
        time.sleep(0.01)

    return {
        "raw": bytes(received),
        "startup_detected": announced_at is not None,
        "armed": armed,
        "finished": finished,
        "detected_mode": detected_mode,
        "detected_design": detected_design,
        "state_before_force": state_before_force,
        "forced_trigger": forced_trigger,
        "trigger_force_s": trigger_force_s,
    }


def save_uart(folder: Path, raw: bytes):
    """Save and validate the 600-row Lab8 telemetry table."""
    (folder / "psoc_uart.txt").write_bytes(raw)
    lines = [line.strip() for line in
             raw.decode("ascii", errors="replace").splitlines()]
    csv_start = next((i for i, line in enumerate(lines)
                      if line.startswith("k,t_us,")), None)
    csv_end = next((i for i, line in enumerate(lines)
                    if line.startswith("# LAB8 END;")), None)
    summary = {
        "uart_bytes": len(raw),
        "uart_end": csv_end is not None,
        "rows": 0,
        "nonzero_flags": None,
        "max_cpu_us": None,
        "median_period_us": None,
    }
    if csv_start is None:
        summary["format_warning"] = "No se encontró cabecera CSV Lab8"
        return summary
    if csv_end is None:
        csv_end = len(lines)
    csv_text = "\n".join(lines[csv_start:csv_end]) + "\n"
    (folder / "psoc_uart.csv").write_text(csv_text, encoding="utf-8")
    table = list(csv.DictReader(io.StringIO(csv_text)))
    summary["rows"] = len(table)
    if not table:
        return summary
    missing = [field for field in UART_FIELDS if field not in table[0]]
    if missing:
        summary["format_warning"] = f"Faltan columnas: {missing}"
        return summary

    try:
        flags = np.asarray([int(row["flags"]) for row in table])
        periods = np.asarray([int(row["intervalo_us"]) for row in table])
        cpu = np.asarray([int(row["cpu_us"]) for row in table])
        y_rel = np.asarray([float(row["y_rel_mV"]) for row in table])
        u_nom = np.asarray([float(row["u_nominal_mV"]) for row in table])
        dac_pos = np.asarray([int(row["dac_pos"]) for row in table])
        dac_neg = np.asarray([int(row["dac_neg"]) for row in table])
        summary.update(
            nonzero_flags=int(np.count_nonzero(flags)),
            max_cpu_us=int(cpu.max()),
            median_period_us=float(np.median(periods[1:])),
            period_min_us=int(periods[1:].min()),
            period_max_us=int(periods[1:].max()),
            y_rel_mean_mV=float(np.mean(y_rel)),
            y_rel_std_mV=float(np.std(y_rel, ddof=1)),
            y_rel_peak_abs_mV=float(np.max(np.abs(y_rel))),
            u_nominal_peak_abs_mV=float(np.max(np.abs(u_nom))),
            dac_pos_peak=int(dac_pos.max()),
            dac_neg_peak=int(dac_neg.max()),
            final_time_us=int(table[-1]["t_us"]),
        )
    except (KeyError, ValueError) as error:
        summary["analysis_warning"] = str(error)
    return summary


def robust_variation(time_s, voltage_v):
    """Return robust screen-trace statistics without filtering the raw data."""
    time_values = np.asarray(time_s, dtype=float).ravel()
    values = np.asarray(voltage_v, dtype=float).ravel()
    result = {"points": int(values.size)}
    if values.size < 2 or time_values.size != values.size:
        return result
    result.update(
        mean_mV=float(np.mean(values) * 1000.0),
        std_mV=float(np.std(values, ddof=1) * 1000.0),
        p05_mV=float(np.quantile(values, 0.05) * 1000.0),
        p95_mV=float(np.quantile(values, 0.95) * 1000.0),
        robust_span_mV=float((np.quantile(values, 0.95) -
                              np.quantile(values, 0.05)) * 1000.0),
        duration_s=float(time_values[-1] - time_values[0]),
    )
    return result


def build_parser():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", default="COM4")
    parser.add_argument("--baud", type=int, default=57600)
    parser.add_argument("--resource", default=None)
    parser.add_argument("--label", default="monitor_lab8")
    parser.add_argument("--expected-mode",
                        choices=("MONITOR", "ABIERTO", "INTEGRAL"),
                        default="MONITOR")
    parser.add_argument("--output", type=Path,
                        default=Path(__file__).resolve().parent /
                        "Capturas_Sincronizadas")
    parser.add_argument("--scale-ch1", type=float, default=0.05)
    parser.add_argument("--scale-ch2", type=float, default=0.02)
    parser.add_argument("--time-scale", type=float, default=0.1)
    parser.add_argument("--trigger-level", type=float, default=0.20)
    parser.add_argument("--arm-delay", type=float, default=2.25)
    parser.add_argument("--rearm-time", type=float, default=3.50)
    parser.add_argument("--force-time", type=float, default=3.60)
    parser.add_argument("--timeout", type=float, default=60.0)
    return parser


def main(argv=None):
    args = build_parser().parse_args(argv)
    if not (0.0 <= args.arm_delay < args.rearm_time < args.force_time < 4.0):
        print("ERROR: requiere armado < rearme < TFOR < 4 s.",
              file=sys.stderr)
        return 2
    if any(value <= 0 for value in
           (args.scale_ch1, args.scale_ch2, args.time_scale, args.timeout)):
        print("ERROR: escalas y timeout deben ser positivos.", file=sys.stderr)
        return 2
    if not (0.0 < args.trigger_level < 5.0 * args.scale_ch1):
        print("ERROR: el trigger debe quedar dentro de ±5 divisiones CH1.",
              file=sys.stderr)
        return 2

    label = re.sub(r"[^a-zA-Z0-9_-]+", "_", args.label).strip("_")
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S_%f")[:-3]
    folder = args.output.resolve() / f"{stamp}_{label or 'lab8'}"
    folder.mkdir(parents=True, exist_ok=False)
    metadata = {
        "local_capture": datetime.now().astimezone().isoformat(timespec="seconds"),
        "expected_mode": args.expected_mode,
        "port": args.port,
        "baud": args.baud,
        "scope_configuration": {
            "ch1_V_div": args.scale_ch1,
            "ch2_V_div": args.scale_ch2,
            "time_s_div": args.time_scale,
            "trigger_V": args.trigger_level,
            "acquisition": "HRES",
            "trigger_source": "CHAN1",
            "trigger_sweep": "NORM",
            "arm_delay_s": args.arm_delay,
            "rearm_time_s": args.rearm_time,
            "force_time_s": args.force_time,
        },
        "firmware_expected_rows": EXPECTED_ROWS,
        "firmware_start_delay_ms": 3000,
    }
    manager = None
    scope = None
    raw = b""
    started = time.perf_counter()
    try:
        print(f"Carpeta ensayo: {folder}", flush=True)
        manager, scope, resource = connect(args.resource)
        metadata["scope_resource"] = resource
        configure_scope(scope, args)
        print(f"Abriendo UART {args.port} a {args.baud} 8N1...", flush=True)
        with serial.Serial(args.port, args.baud, timeout=0.1) as uart:
            uart.reset_input_buffer()
            synchronization = read_uart_and_arm(uart, scope, args)
        raw = synchronization.pop("raw")
        metadata["synchronization"] = synchronization
        metadata["uart"] = save_uart(folder, raw)
        print(f"UART: {metadata['uart']['rows']} filas; "
              f"flags != 0: {metadata['uart']['nonzero_flags']}", flush=True)

        scope_state = scope.query(":TRIG:STAT?").strip().upper()
        metadata["scope_state_before_stop"] = scope_state
        metadata["scope_single_finished"] = scope_state in ("STOP", "TD")
        if not metadata["scope_single_finished"]:
            scope.write(":STOP")

        for channel in ("CHAN1", "CHAN2"):
            print(f"Guardando {channel}...", flush=True)
            time_values, voltage_values, details = acquire_screen_waveform(
                scope, channel)
            save_waveform_csv(folder / f"{channel.lower()}.csv",
                              time_values, voltage_values)
            metadata.setdefault("waveforms", {})[channel] = details
            metadata.setdefault("trace_statistics", {})[channel] = \
                robust_variation(time_values, voltage_values)
        save_screenshot(scope, folder / "pantalla.png")

        uart_summary = metadata["uart"]
        metadata["preliminary_valid"] = bool(
            synchronization["startup_detected"]
            and synchronization["armed"]
            and synchronization["finished"]
            and synchronization["detected_mode"] == args.expected_mode
            and uart_summary["rows"] == EXPECTED_ROWS
            and uart_summary["nonzero_flags"] == 0
            and metadata["scope_single_finished"]
        )
        metadata["total_duration_s"] = round(time.perf_counter() - started, 3)
        save_json(folder / "metadatos.json", metadata)
        print(f"CAPTURA COMPLETA: {folder}", flush=True)
        print(f"VALIDACIÓN PRELIMINAR: {metadata['preliminary_valid']}",
              flush=True)
        return 0 if metadata["preliminary_valid"] else 1
    except (Exception, KeyboardInterrupt) as error:
        metadata["error"] = str(error)
        print(f"ERROR ENSAYO: {error}", file=sys.stderr, flush=True)
        if raw and not (folder / "psoc_uart.txt").exists():
            save_uart(folder, raw)
        save_json(folder / "metadatos.json", metadata)
        return 1
    finally:
        if scope is not None:
            try:
                scope.close()
            except Exception:
                pass
        if manager is not None:
            try:
                manager.close()
            except Exception:
                pass


if __name__ == "__main__":
    raise SystemExit(main())
