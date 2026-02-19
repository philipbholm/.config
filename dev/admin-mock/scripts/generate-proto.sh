#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

mkdir -p src/generated/proto

npx protoc \
  --ts_proto_out=src/generated/proto \
  --ts_proto_opt=outputServices=nice-grpc,outputServices=generic-definitions,useExactTypes=false,esModuleInterop=true \
  --proto_path=api \
  api/admin.proto
