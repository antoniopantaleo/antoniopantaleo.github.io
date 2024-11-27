---
author: Antonio Pantaleo
title: How to create dynamic open-graph images using SwiftUI
date: 2024-10-17T13:00:16+02:00
draft: true
---

TODO 

<!--more-->

[open-graph](https://ogp.me) is a web protocol that adds metadata to a webpage in order to make it more shareable on social media. When you share a link on X, Facebook, or LinkedIn, the platform fetches this metadata and displays it as a preview.

I wanted to be able to create images for my blog posts so like this:

{{< figure width="35%" src="/blog/how-to-create-open-graph-images-with-swiftui/imessage-open-graph.png" >}}

## The SwiftUI part

```swift {hl_lines=[3, 8, 14, 19]}
private static func view(title: String quote: String, image: NSImage) -> some View {
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

[ImageRenderer](https://developer.apple.com/documentation/swiftui/imagerenderer), starting from macOS 13.0+

I wrote a method that uses the `CTFontManagerRegisterFontURLs` to register fonts:

```swift
private func registerFonts() throws {
    let bundle = Bundle.module
    guard let fontsUrls = bundle.urls(forResourcesWithExtension: "ttf", subdirectory: nil), !fontsUrls.isEmpty else {
        throw Error(reason: "Unable to find fonts")
    }
    CTFontManagerRegisterFontURLs(fontsUrls as CFArray, .process, false, nil)
}
```

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

```swift
 static func parseBlogData(_ content: String) async throws -> (title: String, quote: String) {
    let titleRegex = /(?:title:\s+)(.+)/
    let quoteRegex = /---\n*(.+)\n*(?=<!--more-->)/
    
    async let title = extract(regex: titleRegex, from: content)
    async let quote = extract(regex: quoteRegex, from: content)
    
    return try await (title, quote)
}
```

> `extract` is a method that can throw... We use `try` only when accessing its values


## The HTML part

`Go` has a really powerful templating engine [^go-templating] (it reminds me [jinja](https://jinja.palletsprojects.com/en/stable/) for Python) I used to define a `block` in the HTML `head` section, that will host my open graph metadata in every page:

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

The block above will be chosen by default on every page. However I can override it when needed. For example, in my `single.html` (the template used for a single blog post), I can define a new version of open-graph block specific to the single blog post. Some little regex magic brought me here:

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

[^go-templating]: https://pkg.go.dev/html/template