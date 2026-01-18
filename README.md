# Control

Control is a multiplatform (iOS, macOS) SwiftUI client implementation of OpenAPI specification of [Steve's blog](https://github.com/zhufucdev/site).
It serves as a management interface for posting updates, managing images, and curating gallery items.

## Project Structure

- **Control**: The main application source code.
  - **Views**: Contains the UI components
  - **Models**: Data models and caching logic
  - **Utils**: Helper utilities for API client, diffing, debouncing, and image handling
  - **Sync**: Synchronization logic for keeping local state consistent with the server
- **ApiClient**: The auto-generated Swift client for the OpenAPI spec.
  - `Sources/OpenAPIClient`: Contains the generated API logic, models, and infrastructure.
- **Control.xcodeproj**: Xcode project configuration.

## Features

This client implements the following features:

### Update Posts

- List update posts (`GET /update/list`)
- Create new posts (`PUT /update`)
- Edit existing posts (`PATCH /update/{id}`)
- Delete posts (`DELETE /update/{id}`)
- Preview post templates (`GET /update/template`)

### Images

- List uploaded images (`GET /image/list`)
- Upload new images (`POST /image`)
- View image metadata (`GET /image/{id}`)
- Assign images to CDN (`PUT /image`)

### Gallery

- List gallery items (`GET /gallery/list`)
- Add items to the gallery (`PUT /gallery`)
- Edit gallery items (`PATCH /gallery/{id}`)
- Remove items from the gallery (`DELETE /gallery/{id}`)

## Authentication

The API requires a secure **Post Auth Key** for all operations,
which is defined in the web project's environment variables (`POST_AUTH_KEY`).
Ensure this matches the key configured in the Control app settings.

## Libraries

- **KeychainAccess**: For securely storing credentials.
- **SDWebImage**: For asynchronous image downloading and caching.
- **SDWebImageSwiftUI**: SwiftUI integration for SDWebImage.
- **SDWebImageSVGCoder**: SVG support for SDWebImage.
