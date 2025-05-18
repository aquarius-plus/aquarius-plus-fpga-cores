#!/usr/bin/env python3
import struct


files = {}
index_data = b""
content_data = b""


def read_topics():
    topics = []

    with open("_topics.txt", "rt") as f:
        for line in f.readlines():
            line = line.strip()
            if len(line) == 0:
                continue
            if line.startswith("#"):
                continue
            topics.append(line.split(" ", 1))

    topics.sort()
    return topics


def process_file(path):
    global files
    global content_data

    if path in files:
        return

    data = bytearray()
    num_lines = 0

    with open(path, "rt") as f:
        for idx, line in enumerate(f.readlines()):
            line.rstrip()
            if len(line) > 78:
                print(f"{path}:{idx+1} Line too long {len(line)} > 78!")
                exit(1)

            data.append(len(line))
            data.extend(line.encode("latin-1"))
            num_lines += 1

    data = struct.pack("<H", num_lines) + data
    data = struct.pack("<H", len(data)) + data

    offset = len(content_data)
    content_data += data

    files[path] = offset


topics = read_topics()
index_data += struct.pack("<H", len(topics))

for topic in topics:
    process_file(topic[1])

    offset = files[topic[1]]
    index_data += (
        struct.pack("<B", len(topic[0]))
        + topic[0].encode("latin-1")
        + struct.pack("<I", offset)
    )

with open("basic.hlp", "wb") as f:
    f.write(b"HELP" + struct.pack("<H", len(index_data)) + index_data + content_data)
