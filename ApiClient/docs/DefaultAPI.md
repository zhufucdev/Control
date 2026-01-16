# DefaultAPI

All URIs are relative to *http://localhost*

Method | HTTP request | Description
------------- | ------------- | -------------
[**galleryIdDelete**](DefaultAPI.md#galleryiddelete) | **DELETE** /gallery/{id} | Delete Gallery Item
[**galleryIdGet**](DefaultAPI.md#galleryidget) | **GET** /gallery/{id} | Query Gallery Item
[**galleryIdPatch**](DefaultAPI.md#galleryidpatch) | **PATCH** /gallery/{id} | Patch Gallery Item
[**galleryListGet**](DefaultAPI.md#gallerylistget) | **GET** /gallery/list | List Gallery
[**galleryPut**](DefaultAPI.md#galleryput) | **PUT** /gallery | Create Gallery Item
[**imageIdGet**](DefaultAPI.md#imageidget) | **GET** /image/{id} | Query Image Metadata
[**imageListGet**](DefaultAPI.md#imagelistget) | **GET** /image/list | List Images
[**imagePost**](DefaultAPI.md#imagepost) | **POST** /image | Upload Image
[**imagePut**](DefaultAPI.md#imageput) | **PUT** /image | Assign Image to CDN Resource
[**updateIdDelete**](DefaultAPI.md#updateiddelete) | **DELETE** /update/{id} | Delete Update Post
[**updateIdGet**](DefaultAPI.md#updateidget) | **GET** /update/{id} | Query Update Post
[**updateIdPatch**](DefaultAPI.md#updateidpatch) | **PATCH** /update/{id} | Patch Update Post
[**updateListGet**](DefaultAPI.md#updatelistget) | **GET** /update/list | List Update Posts
[**updatePut**](DefaultAPI.md#updateput) | **PUT** /update | Create Update Post
[**updateTemplateGet**](DefaultAPI.md#updatetemplateget) | **GET** /update/template | Update Post Card Template


# **galleryIdDelete**
```swift
    open class func galleryIdDelete(id: Int, completion: @escaping (_ data: JSONValue?, _ error: Error?) -> Void)
```

Delete Gallery Item



### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import OpenAPIClient

let id = 987 // Int | Item identifier

// Delete Gallery Item
DefaultAPI.galleryIdDelete(id: id) { (response, error) in
    guard error == nil else {
        print(error)
        return
    }

    if (response) {
        dump(response)
    }
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **id** | **Int** | Item identifier | 

### Return type

**JSONValue**

### Authorization

[PostAuthKey](../README.md#PostAuthKey)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **galleryIdGet**
```swift
    open class func galleryIdGet(id: Int, completion: @escaping (_ data: JSONValue?, _ error: Error?) -> Void)
```

Query Gallery Item



### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import OpenAPIClient

let id = 987 // Int | Item identifier

// Query Gallery Item
DefaultAPI.galleryIdGet(id: id) { (response, error) in
    guard error == nil else {
        print(error)
        return
    }

    if (response) {
        dump(response)
    }
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **id** | **Int** | Item identifier | 

### Return type

**JSONValue**

### Authorization

[PostAuthKey](../README.md#PostAuthKey)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **galleryIdPatch**
```swift
    open class func galleryIdPatch(id: Int, galleryIdPatchRequest: GalleryIdPatchRequest, completion: @escaping (_ data: GalleryItem?, _ error: Error?) -> Void)
```

Patch Gallery Item



### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import OpenAPIClient

let id = 987 // Int | Item identifier
let galleryIdPatchRequest = _gallery__id__patch_request(locale: SupportedLocale(), tweet: "tweet_example", imageId: 123, trashed: false) // GalleryIdPatchRequest | 

// Patch Gallery Item
DefaultAPI.galleryIdPatch(id: id, galleryIdPatchRequest: galleryIdPatchRequest) { (response, error) in
    guard error == nil else {
        print(error)
        return
    }

    if (response) {
        dump(response)
    }
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **id** | **Int** | Item identifier | 
 **galleryIdPatchRequest** | [**GalleryIdPatchRequest**](GalleryIdPatchRequest.md) |  | 

### Return type

[**GalleryItem**](GalleryItem.md)

### Authorization

[PostAuthKey](../README.md#PostAuthKey)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json, application/octet-stream

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **galleryListGet**
```swift
    open class func galleryListGet(locale: [String]? = nil, limit: Int? = nil, completion: @escaping (_ data: [GalleryItem]?, _ error: Error?) -> Void)
```

List Gallery



### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import OpenAPIClient

let locale = ["inner_example"] // [String] | Accepted locales (optional)
let limit = 987 // Int | At most how many results to return (optional)

// List Gallery
DefaultAPI.galleryListGet(locale: locale, limit: limit) { (response, error) in
    guard error == nil else {
        print(error)
        return
    }

    if (response) {
        dump(response)
    }
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **locale** | [**[String]**](String.md) | Accepted locales | [optional] 
 **limit** | **Int** | At most how many results to return | [optional] 

### Return type

[**[GalleryItem]**](GalleryItem.md)

### Authorization

[PostAuthKey](../README.md#PostAuthKey)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **galleryPut**
```swift
    open class func galleryPut(galleryPutRequest: GalleryPutRequest, completion: @escaping (_ data: Int?, _ error: Error?) -> Void)
```

Create Gallery Item



### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import OpenAPIClient

let galleryPutRequest = _gallery_put_request(locale: "locale_example", tweet: "tweet_example", imageId: 123) // GalleryPutRequest | 

// Create Gallery Item
DefaultAPI.galleryPut(galleryPutRequest: galleryPutRequest) { (response, error) in
    guard error == nil else {
        print(error)
        return
    }

    if (response) {
        dump(response)
    }
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **galleryPutRequest** | [**GalleryPutRequest**](GalleryPutRequest.md) |  | 

### Return type

**Int**

### Authorization

[PostAuthKey](../README.md#PostAuthKey)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json, application/octet-stream

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **imageIdGet**
```swift
    open class func imageIdGet(id: Int, completion: @escaping (_ data: Image?, _ error: Error?) -> Void)
```

Query Image Metadata



### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import OpenAPIClient

let id = 987 // Int | Image identifier

// Query Image Metadata
DefaultAPI.imageIdGet(id: id) { (response, error) in
    guard error == nil else {
        print(error)
        return
    }

    if (response) {
        dump(response)
    }
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **id** | **Int** | Image identifier | 

### Return type

[**Image**](Image.md)

### Authorization

[PostAuthKey](../README.md#PostAuthKey)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json, application/octet-stream

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **imageListGet**
```swift
    open class func imageListGet(completion: @escaping (_ data: [Image]?, _ error: Error?) -> Void)
```

List Images



### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import OpenAPIClient


// List Images
DefaultAPI.imageListGet() { (response, error) in
    guard error == nil else {
        print(error)
        return
    }

    if (response) {
        dump(response)
    }
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**[Image]**](Image.md)

### Authorization

[PostAuthKey](../README.md#PostAuthKey)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **imagePost**
```swift
    open class func imagePost(xAltText: String, xFIleName: String, body: URL, completion: @escaping (_ data: ImagePost201Response?, _ error: Error?) -> Void)
```

Upload Image

Upload image to the CDN via the server as proxy

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import OpenAPIClient

let xAltText = "" // String | Alernative text describing the image content
let xFIleName = "" // String | Name of the original image file
let body = URL(string: "https://example.com")! // URL | 

// Upload Image
DefaultAPI.imagePost(xAltText: xAltText, xFIleName: xFIleName, body: body) { (response, error) in
    guard error == nil else {
        print(error)
        return
    }

    if (response) {
        dump(response)
    }
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **xAltText** | **String** | Alernative text describing the image content | 
 **xFIleName** | **String** | Name of the original image file | 
 **body** | **URL** |  | 

### Return type

[**ImagePost201Response**](ImagePost201Response.md)

### Authorization

[PostAuthKey](../README.md#PostAuthKey)

### HTTP request headers

 - **Content-Type**: application/octet-stream
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **imagePut**
```swift
    open class func imagePut(imagePutRequest: ImagePutRequest, completion: @escaping (_ data: Int?, _ error: Error?) -> Void)
```

Assign Image to CDN Resource

Often used if the image was uploaded on client side

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import OpenAPIClient

let imagePutRequest = _image_put_request(url: "url_example", alt: "alt_example") // ImagePutRequest | 

// Assign Image to CDN Resource
DefaultAPI.imagePut(imagePutRequest: imagePutRequest) { (response, error) in
    guard error == nil else {
        print(error)
        return
    }

    if (response) {
        dump(response)
    }
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **imagePutRequest** | [**ImagePutRequest**](ImagePutRequest.md) |  | 

### Return type

**Int**

### Authorization

[PostAuthKey](../README.md#PostAuthKey)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **updateIdDelete**
```swift
    open class func updateIdDelete(id: Int, completion: @escaping (_ data: UpdatePost?, _ error: Error?) -> Void)
```

Delete Update Post

Note that this endpoint removes the post DIRECTLY without trashing it. Use the PATCH method in such scenario.

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import OpenAPIClient

let id = 987 // Int | 

// Delete Update Post
DefaultAPI.updateIdDelete(id: id) { (response, error) in
    guard error == nil else {
        print(error)
        return
    }

    if (response) {
        dump(response)
    }
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **id** | **Int** |  | 

### Return type

[**UpdatePost**](UpdatePost.md)

### Authorization

[PostAuthKey](../README.md#PostAuthKey)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **updateIdGet**
```swift
    open class func updateIdGet(id: Int, completion: @escaping (_ data: UpdatePost?, _ error: Error?) -> Void)
```

Query Update Post



### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import OpenAPIClient

let id = 987 // Int | 

// Query Update Post
DefaultAPI.updateIdGet(id: id) { (response, error) in
    guard error == nil else {
        print(error)
        return
    }

    if (response) {
        dump(response)
    }
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **id** | **Int** |  | 

### Return type

[**UpdatePost**](UpdatePost.md)

### Authorization

[PostAuthKey](../README.md#PostAuthKey)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **updateIdPatch**
```swift
    open class func updateIdPatch(id: String, updateIdPatchRequest: UpdateIdPatchRequest, completion: @escaping (_ data: UpdatePost?, _ error: Error?) -> Void)
```

Patch Update Post



### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import OpenAPIClient

let id = "id_example" // String | 
let updateIdPatchRequest = _update__id__patch_request(locale: SupportedLocale(), header: "header_example", title: "title_example", summary: "summary_example", cover: 123, mask: Shape(), trashed: false) // UpdateIdPatchRequest | 

// Patch Update Post
DefaultAPI.updateIdPatch(id: id, updateIdPatchRequest: updateIdPatchRequest) { (response, error) in
    guard error == nil else {
        print(error)
        return
    }

    if (response) {
        dump(response)
    }
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **id** | **String** |  | 
 **updateIdPatchRequest** | [**UpdateIdPatchRequest**](UpdateIdPatchRequest.md) |  | 

### Return type

[**UpdatePost**](UpdatePost.md)

### Authorization

[PostAuthKey](../README.md#PostAuthKey)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json, application/octet-stream

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **updateListGet**
```swift
    open class func updateListGet(locale: [String]? = nil, limit: Int? = nil, completion: @escaping (_ data: [UpdatePost]?, _ error: Error?) -> Void)
```

List Update Posts

Get a list of availble updates (the top-most section in highlight page)

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import OpenAPIClient

let locale = ["inner_example"] // [String] | Accepted locale names (optional)
let limit = 987 // Int | At most how many results to return (optional)

// List Update Posts
DefaultAPI.updateListGet(locale: locale, limit: limit) { (response, error) in
    guard error == nil else {
        print(error)
        return
    }

    if (response) {
        dump(response)
    }
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **locale** | [**[String]**](String.md) | Accepted locale names | [optional] 
 **limit** | **Int** | At most how many results to return | [optional] 

### Return type

[**[UpdatePost]**](UpdatePost.md)

### Authorization

[PostAuthKey](../README.md#PostAuthKey)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json, application/octet-stream

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **updatePut**
```swift
    open class func updatePut(updatePutRequest: UpdatePutRequest, completion: @escaping (_ data: Double?, _ error: Error?) -> Void)
```

Create Update Post



### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import OpenAPIClient

let updatePutRequest = _update_put_request(locale: SupportedLocale(), header: "header_example", title: "title_example", summary: "summary_example", cover: 123, mask: Shape()) // UpdatePutRequest | 

// Create Update Post
DefaultAPI.updatePut(updatePutRequest: updatePutRequest) { (response, error) in
    guard error == nil else {
        print(error)
        return
    }

    if (response) {
        dump(response)
    }
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **updatePutRequest** | [**UpdatePutRequest**](UpdatePutRequest.md) |  | 

### Return type

**Double**

### Authorization

[PostAuthKey](../README.md#PostAuthKey)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **updateTemplateGet**
```swift
    open class func updateTemplateGet(completion: @escaping (_ data: JSONValue?, _ error: Error?) -> Void)
```

Update Post Card Template

Variables are wrapped in ${...}.  - ${cover.src} - ${cover.alt} - ${header.leading} - ${header.tailing} - ${title} - ${summary}

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import OpenAPIClient


// Update Post Card Template
DefaultAPI.updateTemplateGet() { (response, error) in
    guard error == nil else {
        print(error)
        return
    }

    if (response) {
        dump(response)
    }
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

**JSONValue**

### Authorization

[PostAuthKey](../README.md#PostAuthKey)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: text/html

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

