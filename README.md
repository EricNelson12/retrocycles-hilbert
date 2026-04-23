# macOS Shortcut Listener

A macOS background utility that listens for shortcut sequences and injects keyboard inputs to draw fun patterns in [RetroCycles](https://www.retrocycles.net/) — a snake/tron-style game where your trail forms the pattern.

## Patterns

- **`:hil` + Enter** — traces a [Hilbert curve](https://en.wikipedia.org/wiki/Hilbert_curve), a space-filling fractal that produces a dense, winding path across the grid
- **`:spi` + Enter** — traces an expanding spiral

## Requirements

- macOS
- Swift compiler (`swiftc`)
- Accessibility permissions granted for the executable

## Setup

Run the build script:

```bash
./run.sh
```

On first run, you'll be prompted to grant Accessibility permissions:

1. Open **System Settings > Privacy & Security > Accessibility**
2. Add the compiled executable
3. Enable the checkbox next to it
4. Re-run `./run.sh`

## How it works

Once running, the listener monitors global keyboard events. When it detects a trigger sequence (e.g. `:hil` followed by Enter), it deletes the typed characters and then fires a precisely-timed series of arrow key presses to steer your RetroCycles trail into the desired shape.

Event injection uses a tag (`0xDEAD`) to distinguish synthetic keystrokes from real ones, preventing feedback loops.
