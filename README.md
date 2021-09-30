# Transifex iOS SDK - Command Line Tool

<p align="left">
<img src="https://img.shields.io/badge/platforms-macOS-lightgrey.svg">
<img src="https://github.com/transifex/transifex-swift-cli/workflows/CI/badge.svg">
</p>

Transifex Command Line Tool uses [Transifex iOS SDK](https://github.com/transifex/transifex-swift/)
to assist developers in pushing and pulling localizations of an iOS application (written in
Swift or Objective-C) to and from Transifex CDS.

For pushing the base localization of the application, the tool uses the `xcodebuild`
command to export the base localization to a temporary folder, then parses the generated
`.xliff` file that contains all the localizable strings of the app and transforms them in the
format that CDS accepts (`TXSourceString`). After getting all the translated strings in the
proper format, it pushes them to CDS. For more information, look into the
[Pushing](#pushing) section of this README.

For pulling the translated localizations, the developer must specify the locale codes and an
output folder, and the command line tool will download them, serialize them in a file
(`txstrings.json`) and store them in the specified folder. For more information, look into
the [Pulling](#pulling) section of this README.

Developer can also use the `invalidate` command to force CDS cache invalidation so
that the next `pull` command will fetch fresh translations from the CDS.

The token and secret strings can be provided by the developer either as arguments in the
command line tool or as enviroment variables (`TRANSIFEX_TOKEN`, `TRANSIFEX_SECRET`).

### Installation

You can either use the tool by typing: `swift run txios-cli` in the root directory of
the project, or you can install the executable to `/usr/local/bin` directory so that you can
call it from any folder.

In order to copy the executable, you can first build the project with
`swift build -c release` and then copy it with
`cp .build/release/txios-cli /usr/local/bin/txios-cli`.

### Usage

The following calls can be either made from within the `TXCli` project directory by:
`swift run txios-cli <cli command>`
or after following the installation instructions above,  from any folder of your computer by:
`txios-cli <cli command>`.

Bear in mind that due to naming collision, the `--verbose` flag won't be detected if the
`txios-cli` is executed via the `swift run` command, as the flag will be applied on the
`swift` executable instead. So to avoid collisions like this, it's recommended to execute
`txios-cli` directly after building it.

For simplicity the following examples will use the latter command.

#### Help

`txios-cli`, `txios-cli -h`, `txios-cli --help`

Displays helpful information for the CLI tool and lists all the subcommands.

`txios-cli [subcommand] --help`

or

`txios-cli help [subcommand]`

Displays helpful information for a subcommand and lists all of its options.

#### Pushing

`txios-cli push --token <transifex_token> --secret <transifex_secret> --project MyApp.xcodeproj`

Exports the base localization of the provided Xcode project, parses the generated XLIFF
file, transforms the translation units to the format Transifex accepts and pushes them to
the Transifex server.

If the developer has already set the enviroment variables mentioned above, then this
command can be simplified to:

`txios-cli push --project MyApp.xcodeproj`

##### Hashing keys on push

By default, the `txios-cli` tool will hash the key of each source string that
is about to be pushed to CDS.

If the developer prefers to maintain the original keys as they already exist in
the application, they can provide the `--disable-hash-keys` option.

The keys are always printed to the console when the `--verbose` option is active.

Example:

`txios-cli push --project MyApp.xcodeproj --verbose`

```
Pushing translations to CDS: [
"hashkey1": "string1"
,
"hashkey2": "string2"
]...
```

`txios-cli push --project MyApp.xcodeproj --verbose --disable-hash-keys`

```
Pushing translations to CDS: [
"string key 1": "string1"
,
"string key 2": "string2"
]...
```

##### Pushing pluralizations limitations

Currently (version 0.1.0) pluralization is supported but only for cases where one variable is
used per pluralization rule. More advanced cases such as nested pluralization rules (for
example: "%d out of %d values entered") will be supported in future releases.

Also, at the moment of writing (version 0.1.0), the `.stringsdict` specification only supports
plural types (`NSStringPluralRuleType`) which is the only possible value of the
`NSStringFormatSpecTypeKey` key ([Ref](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPInternational/StringsdictFileFormat/StringsdictFileFormat.html#//apple_ref/doc/uid/10000171i-CH16-SW4)).

If more rule types are added in the `.stringsdict` specification, the XLIFF parser must be
updated in order to be able to extract them properly and to construct the ICU format out
of them.

Width Variants in `.stringsdict` files are also not currently supported ([Ref](https://help.apple.com/xcode/mac/current/#/devaf8b4090a)).

#### Pulling

`txios-cli pull --token <transifex_token> --translated-locales <translated_locale_list> --output <output_directory>`

Downloads the localizations from Transifex CDS for the specified translated locales, stores
them in a `txstrings.json` file to the output directory specified.

If the developer has already set the enviroment variables mentioned above, then this
command can be simplified to:

`txios-cli pull --translated-locales <translated_locale_list> --output <output_directory>`

#### Invalidating CDS cache

`txios-cli invalidate --token <transifex_token>`

Forces CDS cache invalidation so that the next `pull` command will fetch fresh translations
from CDS.

If the developer has already set the enviroment variable mentioned above, then this
command can be simplified to:

`txios-cli invalidate`

## Minimum Requirements

| Swift           | Xcode           | Platforms                                         |
|-----------------|-----------------|---------------------------------------------------|
| Swift 5.3       | Xcode 12.3      | MacOS 10.13  |

## License

Licensed under Apache License 2.0, see [LICENSE](LICENSE) file.
