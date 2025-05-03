---
author: Antonio Pantaleo
title: Building DSLs in Swift with Result Builders
date: 2025-05-05T12:30:00+02:00
draft: false
---

You’ve all seen the magic of SwiftUI’s syntax, but do you know what makes it possible?

<!--more-->

The secret behind it is a powerful and almost unknown Swift feature introduced in Swift 5.4 by [SE-0289](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0289-result-builders.md) called **Result Builder**, which is described as:

> a new feature which allows certain functions (specially-annotated, often via context) to implicitly build up a result value from a sequence of components

This is exactly what we do when we _declare_ a _sequence_ of components to _build_ a certain `View`:

```swift
var body: some View {
    // First a VStack
    VStack {
        // Which contains a text
        Text("Hello World!")
        // And an image
        Image(systemName: "star")
    }
}
```

The _magic_ is that we construct our type (a `View`) in a closure — without commas or explicit collection handling.
Apple actually uses lots of different `Result Builder`s within its ecosystem in addition to SwiftUI.

---

A `Result Builder` is used within the [RegexBuilder](https://developer.apple.com/documentation/RegexBuilder) framework, that lets us create regular expressions in a simple and declarative way everybody can understand simply reading the code line by line:

```swift
import RegexBuilder

let word = OneOrMore(.word)
let emailRegex = Regex {
    Capture {
        ZeroOrMore {
            word
            "."
        }
        word
    }
    "@"
    Capture {
        word
        OneOrMore {
            "."
            word
        }
    }
}
```

Even [MapKit](https://developer.apple.com/documentation/mapkit/map/init(bounds:interactionmodes:selection:scope:content:)-28wns) started using a `Result Builder` to build `Map` views starting from iOS 17.0:

```swift
import SwiftUI
import MapKit

struct ContentView: View {
    var body: some View {
        Map {
            UserAnnotation()
            Marker(
                "A description",
                systemImage: "mappin",
                coordinate: myCoordinate
            )
        }
    }
}
```

In this article, we’ll learn how to create our own `Result Builder` to build Domain-Specific Languages (DSLs) that make Swift code elegant and expressive.
All the explored examples are taken from my [APUtils](https://github.com/antoniopantaleo/aputils) Swift Package; you can check it out to see the full implementation.

Without further ado, let’s dive in!

## Let’s build a Result Builder

In order to create a `Result Builder`, we need to attach the `@resultBuilder` attribute to a type that will implement the required methods. It exposes different static methods, so using an `enum` is generally a good practice, since we'll never actually instantiate a `@resultBuilder`-conforming type:

```swift
@resultBuilder
enum MyResultBuilder { ... }
```

I like to break the builder definition into four parts:

1. **The base build block**

   Which is the part that actually _builds_ the result. We must implement the following method (in fact it's the only one required to build a `Result Builder`):

   ```swift
   public static func buildBlock(_ components: Component...) -> Component
   ```

   It takes a bunch of `Component`s (where `Component` is a typealias), and creates a single `Component`. You can think of it like a `reduce`; it composes all the parts into a single value — just like SwiftUI takes multiple `View`s and builds one `View`.

2. **Expressions for various types**

   We don't always use the `Component` type. For example, when we are building a SwiftUI's `View` we can use for loops, print statements, expressions like assigning values to variables and so on...
   We manage these kind of extra-types with the following method, where `Expression` is a typealias too:

   ```swift
   public static func buildExpression(_ expression: Expression) -> Component
   ```

   The method acts like a transformation.
   We can override it as many times as we want with different types, so we can support a variety of expressions — such as single elements, arrays, or even custom wrapper types — by providing multiple overloads of `buildExpression`. This flexibility is what allows `Result Builder`s to feel so natural and expressive.

   More advanced `Result Builder`s can implement additional methods like `buildOptional`, `buildEither`, and `buildArray` to support optionals, conditionals, and loops inside the builder closure. This is how you can use `if`, `else`, and `for` statements seamlessly.

   A full list of methods can be found [here](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/attributes/#Result-Building-Methods).

3. **Utility types (Optional)**

   Sometimes we need to work with some kind of values we do not need to transform into a fully working `Component`. With a custom type we can implement a form of [null object pattern](https://en.wikipedia.org/wiki/Null_object_pattern) to represent "empty" or "no-op" cases, or to provide default behaviors for unsupported expressions. This helps keep the builder logic clean and robust, especially when dealing with optional or conditional content.

4. **A handy extension (Optional)**

   Finally, we want our clients to have an API they can consume to use the `Result Builder` directly, hiding the complexity or the `Result Builder`'s concrete type at all. By providing a convenience initializer or static method that takes a builder closure, we make the DSL ergonomic and easy to adopt.

Let's explore some practical examples that will help us understand better what we're talking about.

---

### NSLayoutConstraintsBuilder

Let's build a `Result Builder` that'll help us applying autolayout constraints to our views like in the following example:

```swift
NSLayoutConstraint.activate {
    let fixedSize: CGFloat = 100 // We can create variables
    view.heightAnchor.constraint(equalToConstant: fixedSize)
    if condition { // We can use conditionals, optionals and loops
        view.widthAnchor.constraint(equalToConstant: fixedSize)
    }
    anotherView.topAnchor.constraint(equalTo: view.topAnchor)
}
```

Let's go step by step:

#### 1. The base build block

We want to be able to create a collection of `NSLayoutConstraint`s. So our `Component` has to be of type `[NSLayoutConstraint]`:

```swift
@resultBuilder
public enum NSLayoutConstraintsBuilder {
    public static func buildBlock(_ components: [NSLayoutConstraint]...) -> [NSLayoutConstraint] {
        components.flatMap { $0 }
    }
}
```

We're doing nothing special here. From a bunch of `NSLayoutConstraint`s, we produce the flattened array, collecting all constraints into a single one [^order].

#### 2. Expressions for various types

We now know how to convert a collection of `NSLayoutConstraint`s into an `Array`. What about the single `NSLayoutConstraint`? We need to tell the builder how to transform a single constraint into an array using an `Expression`:

```swift
extension NSLayoutConstraintsBuilder {

    // we define how the builder should handle a single constraint
    public static func buildExpression(_ expression: NSLayoutConstraint) -> [NSLayoutConstraint] {
        [expression]
    }

    // once we define a `buildExpression` method, our `Result Builder` kind of forgets the default `Component` transformation. 
    // we have to tell it how to handle arrays of constraints directly
    public static func buildExpression(_ expression: [NSLayoutConstraint]) -> [NSLayoutConstraint] {
        expression
    }

    // here we transform statements or expressions that return Void (e.g., print statements) into a `Component` as well
    public static func buildExpression(_ expression: Void) -> [NSLayoutConstraint] {
        []
    }

    // other transformations ...
}
```

#### 3. Utility Type

We just used UIKit types directly, so no extra utility types were needed. Actually, we used an empty array in the last snippet that works as a null object. 

#### 4. A handy extension

Finally, to let our clients activate a collection of `NSLayoutConstraint`s built with our `ResultBuilder` we can add the following extension:

```swift
public extension NSLayoutConstraint {
    static func activate(@NSLayoutConstraintsBuilder constraints: () -> [NSLayoutConstraint]) {
        activate(constraints())
    }
}
```

> Thanks to the @resultBuilder attribute, we can now use @NSLayoutConstraintsBuilder as an attribute on closure parameters to inform the compiler that the closure should be interpreted using custom builder logic

---

### AttributedStringBuilder

Pretty easy right?
Let's explore another example, a little bit different. Let's write a `Result Builder` that can build [`AttributedString`](https://developer.apple.com/documentation/foundation/attributedstring)s like this:

```swift
let string = AttributedString {
    "Hello"
    Attributed(\.foregroundColor, .red) {
        Attributed(\.font, .title2) {
            "World"
        }
    }
}
```

which can be rendered to this:

{{< figure width="25%" src="/blog/result-builders/attributed-string.png" >}}

#### 1. The base build block

```swift
@resultBuilder
public enum AttributedStringBuilder {
    public static func buildBlock(_ components: AttributedString...) -> AttributedString {
        guard let last = components.last else { return AttributedString() }
        let separator = AttributedString(" ")
        return components.dropLast().reduce(AttributedString()) { partialResult, component in
            partialResult + component + separator
        } + last
    }
}
```

Nothing fancy here, we are basically joining strings.

#### 2. Expressions for various types

We want to keep it easy and consider two expressions only: the `AttributedString` type itself, and simple `String`s:

```swift
extension AttributedStringBuilder {
    public static func buildExpression(_ expression: AttributedString) -> AttributedString {
        expression
    }

    public static func buildExpression(_ expression: String) -> AttributedString {
        AttributedString(expression)
    }
}
```

#### 3. Utility Type


`AttributedString`s have something called, well, attributes. We can change color, fonts and a lot of other properties of our final string, but we certainly don't want to create an overload for EVERY attribute we can set in an `AttributedString`. What we can do is to create a struct called `Attributed` that makes use of [WritableKeyPath](https://developer.apple.com/documentation/swift/writablekeypath) and recursively considers additional `AttributedStringBuilder`s, so we can nest them as shown in the example above:

```swift
public struct Attributed {
    let attributedString: AttributedString

    public init<Value>(
        _ attribute: WritableKeyPath<AttributeContainer, Value>,
        _ value: Value,
        @AttributedStringBuilder _ builder: () -> AttributedString
    ) {
        var container = AttributeContainer()
        container[keyPath: attribute] = value
        var nestedString = builder()
        for run in nestedString.runs {
            var updatedContainer = run.attributes
            updatedContainer.merge(container)
            nestedString.setAttributes(updatedContainer)
        }
        attributedString = nestedString
    }
}
```

We can then teach our `Result Builder` on how it should transform an `Attributed` type into an `AttributedString` using a new expression:

```swift
extension AttributedStringBuilder {
    public static func buildExpression(_ expression: Attributed) -> AttributedString {
        expression.attributedString
    }
}
```

#### 4. A handy extension

Like in the previous example, we want to provide our clients a nice API to use. We can create an addition initializer to `AttributedString` type:

```swift
public extension AttributedString {
    init(@AttributedStringBuilder _ builder: () -> AttributedString) {
        self = builder()
    }
}
```

---

### URLBuilder

Let's explore one last example. A `Result Builder` that lets us to build an `URL` declaring each component this way:

```swift
let url = URL {
    Scheme("https")
    Host("www.example.com")
    Path("/path")
    URLQueryItem(name: "key", value: "value")
    URLQueryItem(name: "key2", value: "value2")
}
```

This results in the `URL`: `https://www.example.com/path?key=value&key2=value2`

The approach to follow here is a little bit different. We need to manage a heterogeneous set of types that all contribute to building a `URL`. To do this, We can define a common protocol which every `Component` needs to conform to:

```swift
public protocol URLComponentNode {
    func transform(_ urlComponents: URLComponents) -> URLComponents
}
```

#### 1. The base build block

Here, in addition to the `buildBlock` function, we have to use another method provided by `@resultBuilder` called `buildFinalResult`. It gets exectued after the `buildBlock` finishes its work and lets us transform the previously built `Component` into a different object. The final result we want here is a `URL`, not a `URLComponentNode`, so we have to add this additional transformation:

```swift
@resultBuilder
public enum URLBuilder {
    public static func buildBlock(_ components: URLComponentNode...) -> URLComponentNode {
        guard !components.isEmpty else { return EmptyURLComponentNode() }
        let urlComponents = components.reduce(URLComponents()) { partialResult, node in
            node.transform(partialResult)
        }
        return URLComponentsComponentNode(urlComponents: urlComponents)
    }

    public static func buildFinalResult(_ component: URLComponentNode) -> URL? {
        guard let node = component as? URLComponentsComponentNode else { return nil }
        return node.urlComponents.url
    }
}
```

#### 2. Expressions for various types

We need our builder to be able to transform a `URLComponentNode` plus an empy implementation that acts as a null object made possible by a `EmptyURLComponentNode`:

```swift
extension URLBuilder {
    public static func buildExpression(_ expression: Void) -> URLComponentNode {
        EmptyURLComponentNode()
    }

    public static func buildExpression(_ expression: URLComponentNode) -> URLComponentNode {
        expression
    }
}
```

Now that our builder knows how to deal with a `URLComponentNode` type, we need to create a concrete type that conforms to it for each the desired transformation, like the following:

```swift
public struct Host: URLComponentNode {
    private let host: String

    public init(_ host: String) {
        self.host = host
    }

    public func transform(_ urlComponents: URLComponents) -> URLComponents {
        var copy = urlComponents
        copy.host = host
        return copy
    }
}
```

We can define similar types for `Scheme`, `Path`, and so on.

#### 3. Utility Type

We needed two additional types we already saw in the previous examples:

An `EmptyURLComponentNode` that acts as a null object:

```swift
struct EmptyURLComponentNode: URLComponentNode {
    func transform(_ urlComponents: URLComponents) -> URLComponents {
        return urlComponents
    }
}
```

And a `URLComponentsComponentNode` that exposes the components containing all transformations we can later use to build the final `URL`:

```swift
struct URLComponentsComponentNode: URLComponentNode {
    let urlComponents: URLComponents

    init(urlComponents: URLComponents) {
        self.urlComponents = urlComponents
    }

    func transform(_ urlComponents: URLComponents) -> URLComponents {
        urlComponents
    }
}
```

> Note that both of these utility types are `internal`, so users never interact with them directly

#### 4. Handy extension

As always, we can create a custom init to let our clients build their `URL` using our `Result Builder`:

```swift
extension URL {
    public init?(@URLBuilder _ builder: () -> URL?) {
        guard let url = builder() else { return nil }
        self = url
    }
}
```

---

Woah, that was a deep dive! As shown, `Result Builder`s are a powerful feature that allow you to create expressive, type-safe DSLs in Swift. Whether you’re building UI, constructing attributed strings, or assembling URLs, or building basically every kind of component, they help you write code that is both concise, readable and, why not, fun!

[^order]: The order is not relevant here