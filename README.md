# Arkyve

Copyright 2025 Chris Jones

## Introduction

Arkyve is a macOS app for creating, editing and extracting compressed archives. Its main features are:

 * Beautifully native User Interface
 * Wide range of supported archive formats
 * Offers integration with Finder via Quick Actions
 * Offers Shortcuts actions

## FAQ

 1. **Is this project actively maintained?**
    Not really, it is an app that I felt needed to exist, since all of the existing options were not what I was looking for. Arkyve has not shown much popularity, so I am not working on it very much at the moment.
 2. How do I build this?
    You'll need to make sure you have checked out the git sub-modules, and from there you should just be able to change the code signing entity in Xcode and build it.
 3. How do I build the third party libraries?
    There's a script in `vendor/` to do this, and a `Brewfile` to help install some of the required dependencies.
 4. Can I fork this and publish it on the Mac App Store?
    No, the Mac App Store's licensing terms are incompatible with the GPL v2 license that Arkyve is released under.
 5. Can I fork this and publish it outside of the Mac App Store?
    Yes, if and only if you can fully comply with the terms of the GPL v2 license that Arkyve is released under.
 6. Can I use the icon assets?
    No, these are not covered by any open source license terms. If you are forking, you'll need your own icon.
 7. Is this a good codebase to learn from?
    Probably not. I am not a professional macOS developer, but I am very proud of having made Arkyve work and (in my opinion) work really nicely. Convenience trumped elegance in a lot of its internal architecture.

