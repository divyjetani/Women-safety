from __future__ import annotations

import argparse
import os
import platform
import shutil
import sys
from pathlib import Path


def _print_header(title: str) -> None:
    print("\n" + "=" * 80)
    print(title)
    print("=" * 80)


def _env_summary() -> None:
    _print_header("Environment")
    print(f"Python executable : {sys.executable}")
    print(f"Python version    : {sys.version.split()[0]}")
    print(f"Platform          : {platform.platform()}")
    print(f"Working directory : {Path.cwd()}")
    print(f"PATH (first 5)    :")
    for item in os.environ.get("PATH", "").split(os.pathsep)[:5]:
        print(f"  - {item}")


def _import_torch() -> bool:
    _print_header("Step 1: Import torch")
    try:
        import torch

        print("✅ torch import successful")
        print(f"torch version     : {torch.__version__}")
        print(f"torch cuda avail  : {torch.cuda.is_available()}")
        return True
    except Exception as exc:
        print(f"❌ torch import failed: {exc}")
        return False


def _import_whisper() -> bool:
    _print_header("Step 2: Import whisper")
    try:
        import whisper  # noqa: F401

        print("✅ whisper import successful")
        return True
    except Exception as exc:
        print(f"❌ whisper import failed: {exc}")
        return False


def _check_ffmpeg() -> bool:
    _print_header("Step 2.5: Check ffmpeg")
    ffmpeg_path = shutil.which("ffmpeg")
    if ffmpeg_path:
        print(f"✅ ffmpeg found: {ffmpeg_path}")
        return True

    print("❌ ffmpeg not found on PATH")
    print("Install ffmpeg and ensure it is available in PATH.")
    print("Quick Windows install (winget): winget install Gyan.FFmpeg")
    return False


def _load_whisper_model(model_name: str):
    _print_header(f"Step 3: Load whisper model ({model_name})")
    try:
        import whisper

        model = whisper.load_model(model_name)
        print(f"✅ model '{model_name}' loaded")
        return model
    except Exception as exc:
        print(f"❌ model load failed: {exc}")
        return None


def _transcribe(model, audio_file: Path) -> None:
    _print_header(f"Step 4: Transcribe file ({audio_file})")

    if not audio_file.exists():
        print(f"❌ audio file not found: {audio_file}")
        return

    try:
        result = model.transcribe(str(audio_file), fp16=False)
        text = (result.get("text", "") if isinstance(result, dict) else "").strip()
        print("✅ transcription call finished")
        print(f"Detected text: {text if text else '<empty>'}")
    except Exception as exc:
        print(f"❌ transcription failed: {exc}")
        if "WinError 2" in str(exc):
            print("Likely cause: ffmpeg executable is missing from PATH.")


def main() -> int:
    parser = argparse.ArgumentParser(description="Standalone Whisper test for Windows DLL/debug issues")
    parser.add_argument("--model", default="base", help="Whisper model name (default: base)")
    parser.add_argument("--audio", default="", help="Optional path to audio file for transcription")
    args = parser.parse_args()

    _env_summary()

    if not _import_torch():
        return 1

    if not _import_whisper():
        return 1

    ffmpeg_ok = _check_ffmpeg()

    model = _load_whisper_model(args.model)
    if model is None:
        return 1

    if args.audio:
        if not ffmpeg_ok:
            _print_header("Step 4: Transcribe skipped")
            print("Skipping transcription because ffmpeg is missing.")
            _print_header("Result")
            print("Done (with missing dependency).")
            return 1
        _transcribe(model, Path(args.audio))
    else:
        _print_header("Step 4: Transcribe skipped")
        print("No --audio file provided. Model load test completed.")

    _print_header("Result")
    print("Done.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
