# color_extractor_server

A small HTTP endpoint providing color palette extraction from images.

The image can be passed as follows:

- Image URL
- Base64-encoded string

The parameters are as follows:

- `count`: how many colors to extract from the image
- `url`: URL-encoded URL of the source image to fetch
- `base64`: Base64-encoded string of the source image

## Usage

### Installing / Running

#### Easy: Docker image

You can run the server using Docker with the following command:

```bash
docker run -p 8080:8080 color_extractor_server
```

You may need to build the image first using:

```bash
docker build -t color_extractor_server .
```

### API

Submit a HTTP GET request to the server with the desired parameters. For example:

```http
GET /extract?count=5&url=https%3A%2F%2Fexample.com%2Fimage.jpg
```

The server will respond with a JSON array in the body containing the extracted color palette. For example:

```json
["#ff0000", "#00ff00", "#0000ff", "#ffff00", "#00ffff"]
```
