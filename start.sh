#!/bin/bash

podman compose down
podman compose pull
podman compose up -d
