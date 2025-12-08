#!/bin/bash
set -e

# MaintainX Go SDK Generator
# Uses oapi-codegen to generate a Go SDK from the MaintainX OpenAPI spec

OPENAPI_URL="https://api.getmaintainx.com/v1/openapi.json"
SPEC_FILE="openapi.json"
PACKAGE_NAME="maintainx"

echo "==> Downloading OpenAPI spec from $OPENAPI_URL"
curl -sS "$OPENAPI_URL" -o "$SPEC_FILE"
echo "    Downloaded $(wc -c < "$SPEC_FILE") bytes"

echo "==> Fixing issues in OpenAPI spec"

# Use jq to fix the spec
jq '
  # Fix invalid formats: decimal -> double, and remove "format": "integer" (integer is a type, not format)
  walk(
    if type == "object" then
      if .format == "decimal" then .format = "double"
      elif .type == "number" and .format == "integer" then del(.format)
      else .
      end
    else .
    end
  ) |

  # Fix paths
  .paths |= with_entries(
    .key as $path |
    .value |= with_entries(
      .value |= (
        # Extract path parameters from the path
        ($path | [match("\\{([^}]+)\\}"; "g")] | map(.captures[0].string)) as $pathParams |

        # Get existing parameters
        (.parameters // []) as $existingParams |

        # Find missing path parameters
        ($pathParams | map(select(. as $p | ($existingParams | map(select(.in == "path" and .name == $p)) | length) == 0))) as $missingParams |

        # Build new parameters: existing (deduplicated) + missing path params
        (($existingParams | unique_by("\(.in)/\(.name)")) + [
          $missingParams[] | {
            "name": .,
            "in": "path",
            "required": true,
            "schema": {"type": (if . == "id" or (. | test("Id$")) then "integer" else "string" end)}
          }
        ]) as $newParams |

        .parameters = $newParams
      )
    )
  ) |

  # Remove nullable from repeatability property and its oneOf elements
  # Walk through the JSON and when we find a repeatability property with oneOf, remove nullable from the property itself and each oneOf element
  walk(
    if type == "object" and .repeatability? and (.repeatability.oneOf? | type == "array") then
      .repeatability |= (del(.nullable) | .oneOf |= map(if type == "object" then del(.nullable) else . end))
    else .
    end
  )
' "$SPEC_FILE" > "${SPEC_FILE}.tmp" && mv "${SPEC_FILE}.tmp" "$SPEC_FILE"

echo "==> Installing oapi-codegen"
go install github.com/oapi-codegen/oapi-codegen/v2/cmd/oapi-codegen@latest

echo "==> Creating oapi-codegen config files"

# Config for types/models
cat > oapi-codegen-types.yaml << YAML
# yaml-language-server: \$schema=https://raw.githubusercontent.com/oapi-codegen/oapi-codegen/HEAD/configuration-schema.json
package: ${PACKAGE_NAME}
output: types.gen.go
generate:
  models: true
YAML

# Config for client
cat > oapi-codegen-client.yaml << YAML
# yaml-language-server: \$schema=https://raw.githubusercontent.com/oapi-codegen/oapi-codegen/HEAD/configuration-schema.json
package: ${PACKAGE_NAME}
output: client.gen.go
generate:
  client: true
YAML

echo "==> Generating Go SDK"

# Generate types
echo "    Generating types..."
oapi-codegen -config oapi-codegen-types.yaml "$SPEC_FILE"

# Generate client
echo "    Generating client..."
oapi-codegen -config oapi-codegen-client.yaml "$SPEC_FILE"

echo "==> Initializing Go module"
if [ ! -f go.mod ]; then
    go mod init github.com/odenio/maintainx-go-sdk
fi
go mod tidy
go mod vendor

echo "==> Verifying generated code compiles"
go build ./...

echo "==> Done! Generated files:"
ls -la *.gen.go
