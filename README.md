# MaintainX Go SDK

Go client library for the [MaintainX API](https://api.getmaintainx.com/v1/openapi.json).

## Installation

```bash
go get github.com/odenio/maintainx-go-sdk
```

## Usage

```go
package main

import (
	"context"
	"fmt"
	"log"
	"net/http"

	"github.com/odenio/maintainx-go-sdk"
)

func main() {
	// Create a client with bearer token authentication
	client, err := maintainx.NewClient("https://api.getmaintainx.com/v1",
		maintainx.WithRequestEditorFn(func(ctx context.Context, req *http.Request) error {
			req.Header.Set("Authorization", "Bearer YOUR_API_KEY")
			return nil
		}),
	)
	if err != nil {
		log.Fatal(err)
	}

	// List assets
	resp, err := client.GetAssets(context.Background(), &maintainx.GetAssetsParams{})
	if err != nil {
		log.Fatal(err)
	}
	defer resp.Body.Close()

	fmt.Printf("Status: %s\n", resp.Status)
}
```

## Regenerating the SDK

To regenerate the SDK from the latest OpenAPI spec:

```bash
./scripts/generate.sh
```

### Requirements

- Go 1.21+
- [jq](https://jqlang.github.io/jq/) (for patching the OpenAPI spec)
- curl

The script will automatically install [oapi-codegen](https://github.com/oapi-codegen/oapi-codegen).

## API Documentation

See the [MaintainX API Documentation](https://api.getmaintainx.com/v1/openapi.json) for details on available endpoints.

## License

MIT
