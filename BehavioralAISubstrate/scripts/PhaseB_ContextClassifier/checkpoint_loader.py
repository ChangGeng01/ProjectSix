"""Restricted loading for the tensor/primitive checkpoints produced by train.py."""

import torch
from packaging.version import InvalidVersion, Version


def load_classifier_checkpoint(path):
    """Fail closed before loading on versions affected by known loader flaws."""
    raw_version = getattr(torch, "__version__", None)
    requirement = "Checkpoint conversion requires PyTorch >= 2.10.0"
    if not isinstance(raw_version, str):
        raise RuntimeError(f"{requirement}; installed version is unverifiable")
    try:
        version = Version(raw_version)
    except InvalidVersion as error:
        raise RuntimeError(f"{requirement}; installed version is invalid") from error
    if version < Version("2.10.0"):
        raise RuntimeError(f"{requirement}; found {raw_version}")
    return torch.load(path, map_location="cpu", weights_only=True)
