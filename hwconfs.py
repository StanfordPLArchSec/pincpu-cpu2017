
from types import SimpleNamespace as Namespace

hwconfs = {
    "unsafe": Namespace(
        sim = "base",
        script_opts = [],
    ),
    "stt": Namespace(
        sim = "stt",
        script_opts = [
            "--stt",
            "--implicit-channel=Lazy",
            "--speculation-model=Ctrl",
        ],
    ),
}
