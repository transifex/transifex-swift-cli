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

## Transifex Command Line Tool 1.0.1

*September 24, 2021*

- Introduces boolean flag pair (`--enable-hash-keys`/`--disable-hash-keys`) to 
control whether the keys of strings to be pushed should be hashed or not. 
By default the value of this option is `true`, so the keys will be hashed unless
`--disable-hash-keys` is provided.
- Translation keys are now printed next to the source string when `--dry-run`
option is provided.
- Updates Transifex Swift library to 1.0.1.

## Transifex Command Line Tool 1.0.2

*October 26, 2021*

- Introduces parsing directly from an `.xliff` file using the `--project`
argument of the push command.

## Transifex Command Line Tool 1.0.3

*January 14, 2021*

- Fixes regression introduced in 1.0.2 regarding the temporary directory that stores the XLIFF structure being removed prematurely.

## Transifex Command Line Tool 1.0.4

*March 15, 2022*

- Fixes issue where special characters in XLIFF were not producing correct source strings.

## Transifex Command Line Tool 1.0.5

*October 25, 2022*

- Allows users to enter a `.xcworkspace` as a `project` argument and handles it correctly.

## Transifex Command Line Tool 1.0.6

*February 23, 2023*

- Introduces status filter option in pull command.

## Transifex Command Line Tool 2.0.0

*July 7, 2023*

- `push` command now logs any warnings and errors generated during the
processing and push of the source strings.
- Source strings that only exist in files not supported by Transifex SDK are
now ommited.
- Extra options have been introduced for the `push` command:
`--override-tags`, `--override-occurrences`, `--keep-translations`.
- Push logic detects and reports warnings such as duplicate source string keys
or empty source string keys.
- The default value for the `hashKeys` option of the `push` command has been
flipped, so by default the tool **does not** hash the keys of the provided
source strings, respecting the original keys passed by the developer.

## Transifex Command Line Tool 2.1.0

*August 21, 2023*

- Extra option for the `push` command has been introduced: `--excluded-files`
that excludes the provided filenames from processing, filtering out any included
strings.

## Transifex Command Line Tool 2.1.1

*September 21, 2023*

- Adds `--source-locale` option to `pull` command so that developers can specify
the source locale, if it's different than `en`. If not provided, the `pull`
logic default to the `en` source locale.
- Fixes an issue on `push` command where the unsupported SDK files were not
being excluded by the localization parsing logic.
- Addresses language tag discrepancy: In the `push` command, the
`--source-locale` option refers to the source locale of the Xcode project and
the format used by Xcode and iOS is different than the format used by Transifex
(e.g `en-US` instead of `en_US`). For that reason the source locale string is
now normalized before being passed to the exporter logic so that the latter can
always be able to export the source locale from the Xcode project.

## Transifex Command Line Tool 2.1.2

*October 11, 2023*

- Fixes the issue where leading and trailing white space was being added around
the extracted ICU pluralization rules.

## Transifex Command Line Tool 2.1.3

*October 30, 2023*

- Adds base SDK option for push command.

## Transifex Command Line Tool 2.1.4

*March 7, 2024*

- Addresses issue with the `--keep-translations` option of the `push` command
due to inversion. The option has been replaced by the `--delete-translations`
option, in order to allow the underlying `keep_translations` meta flag to be
set to `false`.

## Transifex Command Line Tool 2.1.5

*April 1, 2024*

- Parses and processes the new `.xcstrings` files. Only supports simple
"plural." rules for now.

## Transifex Command Line Tool 2.1.6

*May 29, 2024*

- Adds full support for String Catalogs support.
- Adds support for substitution phrases on old Strings Dictionary file format.
- Updates unit tests.
