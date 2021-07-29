# Transifex Command Line Tool

## Transifex Command Line Tool 0.1.0

*Febrary 4, 2021*

- Public release

## Transifex Command Line Tool 0.5.0

*June 25, 2021*

- Lists found strings on push command.
- Implements dry run on push.
- Changes `--tags` to `--append-tags` for push command.
- Allows content to pulled with specific tags in pull command.
- Formats found strings on push command correctly.

## Transifex Command Line Tool 1.0.0

*July 29, 2021*

- Updates Transifex Swift library to 1.0.0.
- Adds initial value to `withTagsOnly` argument so that is not required.
- Displays custom message when max retries have been exhausted during the push operation.
- Uses animated cursor from CLISpinner library while waiting for a response from CDS when
verbose flag is not provided.
