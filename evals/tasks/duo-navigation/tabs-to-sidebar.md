---
id: duo-navigation/tabs-to-sidebar
skill: duo-navigation
title: Tabs become a sidebar when the phone opens
readme: no
fixture: Places
project: Places.xcodeproj
scheme: Places
build: yes
lint: no
checklist: R6 R10
timeout: 1800
status: ready
---

# Tabs become a sidebar when the phone opens

## Prompt

```text prompt
When the phone is open, show the app's three sections (Places, Gallery, Settings) as a sidebar instead of a tab bar. When it's closed, keep the tab bar. The app must still support iOS 17.
```

## Starting point

Fixture [`Places`](../../fixtures/Places). `RootView` uses a `TabView` with the old `.tabItem` modifiers. The deployment target is iOS 17, so iOS 18 and iOS 27 APIs need availability checks.

## Pass checks

Gate: the app builds for the iPhone Duo simulator (this also proves the availability checks are right).

```sh check sidebar-adaptable
has_src 'tabViewStyle\(\.sidebarAdaptable\)'
```

```sh check sidebar-by-default
# iOS 27.0. Sets the default placement, tab bar or sidebar, of a sidebarAdaptable TabView (reference/api-index.md).
has_src 'defaultTabBarPlacement\(\.sidebar\)'
```

```sh check no-device-switch
# The tab style must not be picked by device type.
no_src 'userInterfaceIdiom *== *\.(pad|phone).*(sidebar|tab)'
```

```sh check launches
xcb_test -only-testing:PlacesUITests
```

## Checklist

- **R6**: open, held wide: a sidebar with the three sections. Closed: the tab items sit in the side bar.
- **R10**: all three sections are reachable closed and open.
