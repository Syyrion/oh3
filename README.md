# Open Hexagon 3

A potential rewrite for Open Hexagon by Vittorio Romeo using Love2D.

*(omg it's finally happening)*

## External dependencies
Apart from the pure lua dependencies that are present in the repositor, the game relies on:
- Love2D
- SQLite

## Tests
Run tests with `love test <module>` in the source directory.
At the moment the only test modules are `replay` and `headless`.
The replay module tests the file format, reading and saving.
The headless module tests replay recording and replaying in headless mode.
Generate coverage statistics with `love test <module> --coverage`
