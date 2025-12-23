---
author: Antonio Pantaleo
title: Expression Patterns in Swift
date: 2025-12-23T17:22:54+01:00
draft: false
tags: [swift]
---

If you’ve ever written Swift code, you’ve encountered expression patterns hundreds of times, even if you didn’t notice it.

<!--more-->

An **expression pattern** is what appears after the keyword `case` in a `switch` statement. The [official documentation](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/patterns/#Expression-Pattern) refers to expression patterns as:

> The value of an expression

When we write a `switch` statement like this:

```swift
switch integerValue {
	case 0:
		print("The value is zero")
	case 1:
		print("The value is one")
	default:
		break
}
```
 what happens under the hood is that Swift calls a special comparison function, similar to the `==` function used for equality. This function is called `~=`.

In fact, by default the `~=` function runs the `==` function to determine if the value we are switching and a given case are equal. The function Swift calls for the example above would be something like this:

```swift
func ~= (pattern: Int, value: Int) -> Bool {
    return pattern == value
}
```

where *pattern* is what appears after the `case` label, and *value* is the current value we are switching on.

## The fun part

Now that we know how `switch` statements work, how could this help us? The real power of the `~=` function is that it can be overloaded to suit our needs.

Let's explore some examples:

### Regex

If we define an overload of `~=` as follows:

```swift
func ~=<RegexOutput>(pattern: any RegexComponent<RegexOutput>, value: String) -> Bool {
    !value.matches(of: pattern).isEmpty
}
```

we unlock the power of [Swift 5.7’s regular expressions](https://developer.apple.com/documentation/swift/regex) to be used inside a `switch` statement like in the following example:

```swift
switch "user@email.com" {
    case /^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/:
        logger.debug("Valid email")
    default:
        logger.debug("Invalid email")
}
// The code logs "Valid email"
```

### Flexibility is the key

We can go even further than that. Let's consider this `User` struct:

```swift
struct User {
    enum Role {
        case admin
        case standard
    }
    let name: String
    let role: Role
    let lastAccess: Date? = nil
}
```

we can create a custom type and define an overload of `~=` that uses that type. It doesn’t even need to be a new type.
Here I define just a `typealias`:

```swift
typealias Predicate<Root> = (Root) -> Bool

func ~=<Root>(pattern: Predicate<Root>, value: Root) -> Bool {
    pattern(value)
}
```

we can then define our predicates based on what we're interested in:

```swift
let recentlyLogged: Predicate<User> = { user in
    guard let lastAccess = user.lastAccess else { return false }
    return lastAccess > .now.addingTimeInterval(-3600)
}

let isAdmin: Predicate<User> = { $0.role == .admin }
```

and end up with a clear and self-explanatory `switch` statement:

```swift
switch user {
    case recentlyLogged:
        logger.debug("User logged recently")
    case isAdmin:
        logger.debug("User is admin")
    default:
        break
}
```

---

## My 2 cents

I often declare my `~=` overrides as `fileprivate` methods wherever I need them, to avoid polluting my application with unnecessary functions.