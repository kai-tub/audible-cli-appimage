# Unofficial [audible-cli](https://github.com/mkb79/audible-cli) AppImage

This repository contains the necessary plumbing to create an **unofficial** self-contained
[audible-cli](https://github.com/mkb79/audible-cli) [AppImage](https://appimage.org/)
that can run on _any_ Linux distribution.

The latest version can be downloaded from the [GitHub Releases](https://github.com/kai-tub/audible-cli-appimage/releases/).

The AppImage _includes_ all the example plugins from upstream, such as:
- [decrypt](https://github.com/mkb79/audible-cli/blob/master/plugin_cmds/cmd_decrypt.py)
- [get-annotations](https://github.com/mkb79/audible-cli/blob/master/plugin_cmds/cmd_get-annotations.py)
- [goodreads-transform](https://github.com/mkb79/audible-cli/blob/master/plugin_cmds/cmd_goodreads-transform.py)
- [image-url](https://github.com/mkb79/audible-cli/blob/master/plugin_cmds/cmd_image-urls.py)
- [listening-stats](https://github.com/mkb79/audible-cli/blob/master/plugin_cmds/cmd_listening-stats.py)

Probably the most useful being the `decrypt` plugin that allows decryption of the
proprietary AAX and AAXC files with a users credentials.
But please note that the plugin is meant as a proof-of-concept and for testing purposes only.

Since the `decrypt` plugin is a thin wrapper around [ffmpeg](https://www.ffmpeg.org/), the
generated `AppImage` also contains the required libraries for ffmpeg.
Hopefully making the `decrypt` plugin more accessible for testers.

## Nix

To generate the `AppImage`, [nix](nixos.org), or more concretely [nix-appimage](https://github.com/ralismark/nix-appimage/tree/main),
is used. To follow the `audible-cli` upstream more closely, this project uses its own local
`flake.nix` file to build the packages/dependencies for more fine-grained control compared to the
[audible-cli package from nixpkgs](https://search.nixos.org/packages?channel=23.11&show=audible-cli&from=0&size=50&sort=relevance&type=packages&query=audible-cli).
If you are using `nix` already and only need the `audible-cli` package, I would recommended
using [audible-cli package from nixpkgs](https://search.nixos.org/packages?channel=23.11&show=audible-cli&from=0&size=50&sort=relevance&type=packages&query=audible-cli).
Use this repository as an input, if you would like to have access to the example plugins as well.

## Status

This is an **unofficial** repository! If you have any issues with executing the AppImage or
anything related to the nix files, please report them here!

If `audible-cli` or the `AppImage` is helpful to you,
please consider [supporting the upstream development](https://github.com/sponsors/mkb79)!



