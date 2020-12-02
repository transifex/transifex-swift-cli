# Transifex Command Line Tool

Transifex Command Line Tool is a command line tool that can assist  developers in 
pushing the base localizations of an iOS application (ObjC or Swift) to Transifex.

The tool uses `xcodebuild` command line tool to export the base localization to a
temporary folder, then parses the generated `.xliff` file that contains all the localizable
strings of the app and transforms them in the format that Transifex accepts. After getting
all the translated strings in a proper form, it pushes them to CDS using the provided
token and secret provided by the developer either as arguments in the command line tool 
or as enviroment variables (`TRANSIFEX_TOKEN`, `TRANSIFEX_SECRET`).

### Installation

You can either use the tool by typing: `swift run transifex` in the root directory of the 
project, or you can install the executable to `/usr/local/bin` directory so that you can
call it from any folder.

In order to copy the executable, you can first build the project with 
`swift build -c release` and then copy it with
`cp .build/release/transifex /usr/local/bin/`. 

### Usage

`transifex`, `transifex -h`, `transifex --help`

Displays a help dialog with all the subcommands.

`transifex push --token <transifex_token> --secret <transifex_secret> --project MyApp.xcodeproj`

Exports the base localization of the provided Xcode project, parses the generated XLIFF
file, transforms the translation units to the format Transifex accepts and pushes them to
the Transifex server.

If the developer has already set the enviroment variables mentioned above, then this
command can be simplified to:

`transifex push --project MyApp.xcodeproj`
