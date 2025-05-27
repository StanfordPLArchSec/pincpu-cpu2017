import types

hwconfs = {
    "unsafe": types.SimpleNamespace(
        sim = "base",
        script_opts = [],
    ),
    "stt": types.SimpleNamespace(
        sim = "stt",
        script_opts = [
            "--stt",
            "--implicit-channel=Lazy",
            "--speculation-model=Ctrl",
        ],
    ),
}
