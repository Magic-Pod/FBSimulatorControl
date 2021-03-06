#!/usr/bin/env python3
# Copyright (c) Facebook, Inc. and its affiliates. All Rights Reserved.

from typing import List

from idb.grpc.idb_pb2 import MvRequest
from idb.grpc.types import CompanionClient


async def client(
    client: CompanionClient, bundle_id: str, src_paths: List[str], dest_path: str
) -> None:
    await client.stub.mv(
        MvRequest(bundle_id=bundle_id, src_paths=src_paths, dst_path=dest_path)
    )
