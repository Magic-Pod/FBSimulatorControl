#!/usr/bin/env python3
# Copyright (c) Facebook, Inc. and its affiliates. All Rights Reserved.

from idb.grpc.idb_pb2 import ClearKeychainRequest
from idb.grpc.types import CompanionClient


async def client(client: CompanionClient) -> None:
    await client.stub.clear_keychain(ClearKeychainRequest())
