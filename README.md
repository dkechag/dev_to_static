# dev_to_static.pl

A Perl script to create a static copy of your DEV (dev.to) blog.

This tool fetches your DEV posts using the public API and generates a complete static HTML site.
It's useful if you want to host your content elsewhere, reach readers where DEV might be blocked, or have more control over your blog’s presentation.

---

## Features

- Static HTML for each article, canonical URL from DEV.to.
- Sidebar navigation with articles and tags.
- Index page and per-tag index pages0
- Syntax highlighting using highlight.js.
- Default dark theme (style.css).

### Missing DEV.to functionality

- DEV comments and reactions are not imported, a link to the original DEV article is shown to users for this functionality.

---

## Requirements

- Perl 5 (down to 5.10 tested, may work on even more ancient versions).
- The following CPAN modules:
  - `LWP::UserAgent`
  - `JSON`
  - `Path::Tiny`

---

## Usage

You need to specify at least your DEV user name when calling the script:

```
./dev_to_static.pl -u <username>

# or to also specify a target directory and name your blog:
./dev_to_static.pl -u <username> -t <directory> -title="Blog name"
```

See option `-h` to get more help.

You can adapt `style.css` to your own theme and use your own `favicon.png`. Any assets you add to your theme, save them at the script's directory and provide their filenames to the `-a` argument so that they are copied to the target directory.

You can run the script on your web host, or run locally and copy the resulting directory to your host (scp/FTP/rsync etc).

To keep your mirror up to date, you can set up a nightly cron job.

---

## License

MIT - free to use, modify, and redistribute. Attribution appreciated.
