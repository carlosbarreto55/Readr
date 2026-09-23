## Why

On device, Browse's sources open once; after going back, tapping a source does
nothing. Library cards, Downloads series headers, and Series chapters behave the
same way after returning. Every screen's navigation stops working the first time
the reader leaves it and comes back.

## What Changes

- Each time a screen appears it receives a live stream of its model's navigation
  effects, so taps navigate no matter how many times the reader has left and
  returned.
- Effects sent while no screen is listening are delivered when one next listens.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `app-shell-navigation`: a destination stays navigable after the reader returns
  to it.

## Impact

- **Core:** a single-subscriber effect channel.
- **UI:** the five presentation models (Browse, Library, Series, Reader,
  Downloads) publish effects through it. Screens and tests are unchanged in
  shape.

## Non-goals

- Changing any route, effect, or navigation destination.
