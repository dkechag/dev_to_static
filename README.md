# dev_to_static

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

Change 2 lines in dev.to.pl with your username and your desired blog name:

```
my $username = 'your_dev_to_username';
my $blogname = "your_blog_name";
```

Generate the static site to a `target_directory`:


```
perl dev.to.pl target_directory
```

You can run it on your web host, or run locally and copy the resulting directory to your host (scp/FTP/rsync etc).

To keep your mirror up to date, you can set up a nightly cron job.

---

## License

MIT - free to use, modify, and redistribute. Attribution appreciated.
