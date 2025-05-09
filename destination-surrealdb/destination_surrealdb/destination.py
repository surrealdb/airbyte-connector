#
# Copyright (c) 2025 Airbyte, Inc., all rights reserved.
#

import datetime
import json
import logging
import os
import uuid
from collections import defaultdict
from logging import getLogger
from typing import Any, Dict, Iterable, List, Mapping

from surrealdb import Surreal

from airbyte_cdk.destinations import Destination
from airbyte_cdk.models import AirbyteConnectionStatus, AirbyteMessage, ConfiguredAirbyteCatalog, DestinationSyncMode, Status, Type

logger = getLogger("airbyte")

CONFIG_SURREALDB_URL = "surrealdb_url"
CONFIG_SURREALDB_NAMESPACE = "surrealdb_namespace"
CONFIG_SURREALDB_DATABASE = "surrealdb_database"
CONFIG_SURREALDB_TOKEN = "surrealdb_token"
CONFIG_SURREALDB_USERNAME = "surrealdb_username"
CONFIG_SURREALDB_PASSWORD = "surrealdb_password"

def normalize_url(url: str) -> str:
    """
    Get a normalized version of the destination url.
    Translate rocksdb:NAME, surrealkv:NAME, and file:NAME to rocksdb://NAME, surrealkv://NAME, and file://NAME respectively.
    """
    if "://" not in url:
        components = url.split(":")
        if len(components) == 2:
            return f"{components[0]}://{components[1]}"
        else:
            raise ValueError(f"Invalid URL: {url}")

    return url

def surrealdb_connect(config: Mapping[str, Any]) -> Surreal:
    """
    Connect to SurrealDB.

    Args:
        config (Mapping[str, Any]): SurrealDB connection config
        config[CONFIG_SURREALDB_URL]: SurrealDB URL
        config[CONFIG_SURREALDB_NAMESPACE]: SurrealDB namespace
        config[CONFIG_SURREALDB_DATABASE]: SurrealDB database
        config[CONFIG_SURREALDB_TOKEN]: SurrealDB token
        config[CONFIG_SURREALDB_USERNAME]: SurrealDB username
        config[CONFIG_SURREALDB_PASSWORD]: SurrealDB password

    Returns:
        Surreal: SurrealDB client
    """
    url = str(config.get(CONFIG_SURREALDB_URL))
    url = normalize_url(url)
    if url.startswith("surrealkv:") or url.startswith("rocksdb:") or url.startswith("file:"):
        components = url.split("://")
        logger.info("Using %s at %s", components[0], components[1])
        os.makedirs(os.path.dirname(components[1]), exist_ok=True)

    signin_args = {}
    if CONFIG_SURREALDB_TOKEN in config:
        signin_args["token"] = str(config[CONFIG_SURREALDB_TOKEN])
    if CONFIG_SURREALDB_USERNAME in config:
        signin_args["username"] = str(config[CONFIG_SURREALDB_USERNAME])
    if CONFIG_SURREALDB_PASSWORD in config:
        signin_args["password"] = str(config[CONFIG_SURREALDB_PASSWORD])

    con = Surreal(url=url)
    if signin_args.keys().__len__() > 0:
        con.signin(signin_args)
    return con

class DestinationSurrealDB(Destination):
    """
    Destination connector for SurrealDB.
    """
    def write(
        self, config: Mapping[str, Any], configured_catalog: ConfiguredAirbyteCatalog, input_messages: Iterable[AirbyteMessage]
    ) -> Iterable[AirbyteMessage]:

        """
        Reads the input stream of messages, config, and catalog to write data to the destination.

        This method returns an iterable (typically a generator of AirbyteMessages via yield) containing state messages received
        in the input message stream. Outputting a state message means that every AirbyteRecordMessage which came before it has been
        successfully persisted to the destination. This is used to ensure fault tolerance in the case that a sync fails before fully completing,
        then the source is given the last state message output from this method as the starting point of the next sync.

        :param config: dict of JSON configuration matching the configuration declared in spec.json
        :param configured_catalog: The Configured Catalog describing the schema of the data being received and how it should be persisted in the
                                    destination
        :param input_messages: The stream of input messages received from the source
        :return: Iterable of AirbyteStateMessages wrapped in AirbyteMessage structs
        """
        streams = {s.stream.name for s in configured_catalog.streams}
        logger.info("Starting write to SurrealDB with %d streams", len(streams))

        con = surrealdb_connect(config)

        namespace = str(config.get(CONFIG_SURREALDB_NAMESPACE))
        database = str(config.get(CONFIG_SURREALDB_DATABASE))

        con.query(f"DEFINE NAMESPACE IF NOT EXISTS {namespace};")
        con.query(f"DEFINE DATABASE IF NOT EXISTS {database};")
        con.use(namespace, database)

        for configured_stream in configured_catalog.streams:
            name = configured_stream.stream.name
            table_name = f"_airbyte_raw_{name}"
            if configured_stream.destination_sync_mode == DestinationSyncMode.overwrite:
                # delete the tables
                logger.info("Removing table for overwrite: %s", table_name)
                con.query(f"REMOVE TABLE IF EXISTS {table_name};")

            # create the table if needed
            con.query(f"DEFINE TABLE IF NOT EXISTS {table_name};")
            con.query(f"DEFINE FIELD IF NOT EXISTS _airbyte_ab_id ON {table_name} TYPE string;")
            con.query(f"DEFINE FIELD IF NOT EXISTS _airbyte_emitted_at ON {table_name} TYPE datetime;")
            con.query(f"DEFINE FIELD OVERWRITE _airbyte_data ON {table_name} TYPE string;")

        buffer = defaultdict(lambda: defaultdict(list))

        for message in input_messages:
            if message.type == Type.STATE:
                # flush the buffer
                for stream_name in buffer.keys():
                    logger.info("flushing buffer for state: %s", message)
                    DestinationSurrealDB._flush_buffer(con=con, buffer=buffer, stream_name=stream_name)

                buffer = defaultdict(lambda: defaultdict(list))
                
                yield message
            elif message.type == Type.RECORD:
                data = message.record.data
                stream_name = message.record.stream
                if stream_name not in streams:
                    logger.debug("Stream %s was not present in configured streams, skipping", stream_name)
                    continue
                # add to buffer
                buffer[stream_name]["_airbyte_ab_id"].append(str(uuid.uuid4()))
                buffer[stream_name]["_airbyte_emitted_at"].append(datetime.datetime.now())
                buffer[stream_name]["_airbyte_data"].append(json.dumps(data))

            else:
                logger.info("Message type %s not supported, skipping", message.type)
                    
        # flush any remaining messages
        for stream_name in buffer.keys():
            DestinationSurrealDB._flush_buffer(con=con, buffer=buffer, stream_name=stream_name)

    @staticmethod
    def _flush_buffer(*, con: Surreal, buffer: Dict[str, Dict[str, List[Any]]], stream_name: str):
        table_name = f"_airbyte_raw_{stream_name}"
        buf = buffer[stream_name]
        buf_ids = buf["_airbyte_ab_id"]
        buf_emitted_at = buf["_airbyte_emitted_at"]
        buf_data = buf["_airbyte_data"]
        for i, _id in enumerate(buf_ids):
            emitted_at = buf_emitted_at[i]
            data = buf_data[i]
            con.upsert(f"{table_name}:{_id}", {"_airbyte_ab_id": _id, "_airbyte_emitted_at": emitted_at, "_airbyte_data": data})


    def check(self, logger: logging.Logger, config: Mapping[str, Any]) -> AirbyteConnectionStatus:
        """
        Tests if the input configuration can be used to successfully connect to the destination with the needed permissions
            e.g: if a provided API token or password can be used to connect and write to the destination.

        :param logger: Logging object to display debug/info/error to the logs
            (logs will not be accessible via airbyte UI if they are not passed to this logger)
        :param config: Json object containing the configuration of this destination, content of this json is as specified in
        the properties of the spec.json file

        :return: AirbyteConnectionStatus indicating a Success or Failure
        """
        try:
            con = surrealdb_connect(config)
            logger.debug("Connected to SurrealDB. Running test query.")
            con.query("SELECT * FROM [1];")
            logger.debug("Test query succeeded.")

            return AirbyteConnectionStatus(status=Status.SUCCEEDED)
        except Exception as e:
            return AirbyteConnectionStatus(status=Status.FAILED, message=f"An exception occurred: {repr(e)}")
        
