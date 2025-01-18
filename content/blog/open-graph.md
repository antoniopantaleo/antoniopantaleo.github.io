---
author: Antonio Pantaleo
title: Auto-Generate blog post images with SwiftUI
date: 2025-01-18T13:00:16+02:00
draft: true
---

SwiftUI and HTML make a great team, turning information into beautiful, shareable images -- automatically.

<!--more-->

The key to this collaboration is named [Open Graph](https://ogp.me), a protocol that enhances web page metadata, making content more shareable on platforms like Twitter, Facebook, LinkedIn and others. 
When sharing a link, these platforms extract Open Graph metadata to create a visual preview, often including a title and an image.

I wanted to dynamically generate images for my blog posts and share them beautifully like this:

{{< figure width="35%" src="/blog/how-to-create-open-graph-images-with-swiftui/imessage-open-graph.png" >}}

What a perfect opportunity for me to explore more web-oriented technologies and integrate Swift, my favourite language, into them!

## The Swift part

To streamline the process and make it versatile, I wrote a binary executable program that can be launched directly from the terminal or integrated into a CI environment (e.g. GitHub Actions). I developed it as a Swift Package using the [Swift Argument Parser](https://apple.github.io/swift-argument-parser/documentation/argumentparser/) library.

You can find the source code of this package [here](https://github.com/antoniopantaleo/OpenGraphKit).

### View

SwiftUI is an incredible tool for fast prototyping and designing graphical content.
I created a simple view that includes the blog post title, a short description and an image [^image] of my Memoji:

```swift {hl_lines=[3, 8, 14, 19]}
private static func view(title: String, quote: String, image: NSImage) -> some View {
    // A background
    Color.thumbnailBackground
        .frame(width: width, height: height)
        .overlay {
            HStack(spacing: 80) {
                // My memoji 
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 550)
                VStack(alignment: .leading, spacing: 30) {
                    // Blog post title 
                    Text(title)
                        .foregroundStyle(.white)
                        .font(.custom("Inter", size: 130))
                        .fontWeight(.bold)
                    // Blog post quote
                    Text(quote)
                        .foregroundStyle(.white.opacity(0.7))
                        .font(.custom("Inter", size: 50))
                        .fontWeight(.light)
                }
            }
            .padding(50)
        }
}
```

I wanted to use a custom font, and since I was writing a Swift Package, I needed a way to register it at runtime when launching the script.
I found Swift provides a handy method that worked perfectly for this: [CTFontManagerRegisterFontURLs](https://developer.apple.com/documentation/coretext/1499468-ctfontmanagerregisterfontsforurl).

```swift
private func registerFonts(from bundle: Bundle) throws {
    guard let fontsUrls = bundle.urls(forResourcesWithExtension: "ttf", subdirectory: nil), !fontsUrls.isEmpty else {
        throw Error(reason: "Unable to find fonts")
    }
    CTFontManagerRegisterFontURLs(fontsUrls as CFArray, .process, false, nil)
}
```

I then needed to somehow convert this view into an image. Luckily, the SwiftUI framework introduced a type call [ImageRenderer](https://developer.apple.com/documentation/swiftui/imagerenderer) starting from macOS 13.0+ that (as you can guess) renders a view into image binary data. It works like taking a snapshot of a view.

I wrote a simple method to achieve this:

```swift
static func createThumbnailImage(title: String, quote: String) throws -> Data {
    guard let scaleFactor =  NSScreen.main?.backingScaleFactor else {
        throw OpenGraphKit.Error(reason: "Unable to generate image")
    }
    let profileImage = try getProfileImage()
    let renderer = ImageRenderer(
        content: view(
            title: title, 
            quote: quote, 
            image: profileImage
        )
    )
    renderer.scale = scaleFactor // This is used to get a higher resolution image
    let image = renderer.cgImage
    guard let data = image?.png, !data.isEmpty else {
        throw OpenGraphKit.Error(reason: "Unable to generate image data")
    }
    return data
}
```

### Content

Now that I could create images with a title and description, I needed to extract this information from my blog posts.
Before Swift 6, Swift's new RegEx syntax had to be explicitly enabled as an opt-in feature in the Package.swift manifest to use it.

```swift {hl_lines=[13,14,15]}
// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "OpenGraphKit",
    platforms: [.macOS(.v13)],
    products: ...,
    dependencies: ...,
    targets: [
        .target(
            name: "OpenGraphKit",
            swiftSettings: [
                .enableUpcomingFeature("BareSlashRegexLiterals")
            ]
        ),
        ...
    ]
)
```

In Swift 6, this feature is enabled by default, simplifying the manifest:

```diff
- // swift-tools-version: 5.10
+ // swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "OpenGraphKit",
    platforms: [.macOS(.v13)],
    products: ...,
    dependencies: ...,
    targets: [
        .target(
-             name: "OpenGraphKit",
+             name: "OpenGraphKit"
-             swiftSettings: [
-                 .enableUpcomingFeature("BareSlashRegexLiterals")
-             ]
        ),
        ...
    ]
)
```

I wrote a simple function using the `/regex/` notation to extract the necessary information from a given blog post file:

```swift
 static func parseBlogData(_ content: String) async throws -> (title: String, quote: String) {
    let titleRegex = /(?:title:\s+)(.+)/
    let quoteRegex = /---\n*(.+)\n*(?=<!--more-->)/
    
    async let title = extract(regex: titleRegex, from: content)
    async let quote = extract(regex: quoteRegex, from: content)
    
    return try await (title, quote)
}
```

Cool! I can now generate a thumbnail of any post just running a script.

Now comes the more "dynamic" part. How do I use these images?

## The HTML part

This website is built using [HUGO](https://gohugo.io) framework. `Go` has a powerful [templating engine](https://pkg.go.dev/html/template) (it reminds me [jinja](https://jinja.palletsprojects.com/en/stable/) for Python) which I used to define a `block` in the HTML `head` section that hosts Open Graph metadata for every page of my website. It looks like this:

```go-html-template
<!DOCTYPE html>
<html lang="{{ .Site.LanguageCode }}">
  <head>
    <!-- other configurations ... --> 
    {{ block "open-graph" . }}
    <meta property="og:title" content="{{ .Title }}" />
    <meta property="og:description" content="{{ .Site.Params.homepage.description }}" />
    <meta property="og:image" content="https://antoniopantaleo.dev/open-graph/homepage.png" />
    {{ end }}
    <!-- other configurations ... -->
    </head>
</html>
```

The block above will be chosen by default on every page. However, I can override it everywhere I need to. For example, in my `single.html` (the template I use for a single blog post), I can define a new version of open-graph block specific to the single blog post. Some little regex magic (the same I used in the Swift script) brought me here:

```go-html-template 
{{ define "open-graph" }}
<!-- A little bit of text manipulation, in order to extract the informations I need -->
{{ $file := printf "content/blog/%s.md" .File.BaseFileName }}
{{ $content := readFile $file }}
{{ $split := split $content "<!--more-->" }}
{{ $firstPart := index $split 0 }}
{{ $quote := replaceRE "^---(.|\n)*?---" "" $firstPart }}
<!-- Here I override the default open-graph metadata -->
<meta property="og:title" content="{{ .Title }}" />
<meta property="og:description" content="{{ $quote }}" />
<meta property="og:image" content="{{ printf "https://antoniopantaleo.dev/open-graph/%s.png" .File.BaseFileName }}" />
{{ end }}
```

The code above will populate each blog post web page, selecting the correct title, description and image file.

And thats's it! No more manual image generation. SwiftUI (and Open Graph) handle it all for me.

[^image]: Here the type is `NSImage` because of the running target to be MacOS
