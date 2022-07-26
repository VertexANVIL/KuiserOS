#!/usr/bin/env python3
# Seals and unseals FDE secrets

import json
import argparse
import tpm2_pytss.tcti

from typing import List

class KeyProtector():
    """
    Represents a key protector that can be used to seal or unseal data.
    """
    def seal(plaintext: str) -> str:
        raise NotImplementedError()

    def unseal(plaintext: str) -> str:
        raise NotImplementedError()


class TPM2KeyProtector():
    def seal(plaintext: str) -> str:
        pass

    def unseal(plaintext: str) -> str:
        pass


class VaultKeyProtector():
    def seal(plaintext: str) -> str:
        pass

    def unseal(plaintext: str) -> str:
        pass


class CryptoController():
    def __init__(self, protectors: List[KeyProtector]):
        self._protectors = protectors

    def seal(plaintext: str) -> str:
        pass

    def unseal(plaintext: str) -> str:
        pass


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Seal and unseal FDE secrets")
    parser.add_argument("-c", "--config", type=str, required=True, help="Path to the configuration file containing key protector definitions")
    parser.add_argument("-p", "--protectors", type=str, required=True, help="Comma-separated names of protectors to use")

    subparsers = parser.add_subparsers(
        dest="operation",
    )
    subparsers.required = True

    seal_parser = subparsers.add_parser("seal", help="Seals plaintext against one or more key protectors")
    seal_parser.add_argument("plaintext", nargs=1)

    unseal_parser = subparsers.add_parser("unseal", help="Unseals ciphertext against one or more key protectors")
    unseal_parser.add_argument("ciphertext", nargs=1)

    return parser.parse_args()

args = parse_args()
with open(args.config, "r") as f:
    config = json.load(f)

protector_types = {
    "tpm2": TPM2KeyProtector,
    "vault": VaultKeyProtector
}

print(config)
