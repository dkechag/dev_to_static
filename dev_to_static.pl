#!/usr/bin/env perl

use utf8;
use strict;
use warnings;
use Getopt::Long;
use HTTP::Message;
use JSON;
use LWP::UserAgent;
use Path::Tiny;
use Pod::Usage;
use Time::Piece;

=head1 NAME

dev_to_static.pl

=head1 SYNOPSIS

 ./dev_to_static.pl -u <username> [options]

 Options:
 -user      | -u <name> : DEV user name (required).
 -target    | -t <dir>  : Target directory.
 -title <blog_title>    : Blog title (Default: "<username>'s blog").
 -assets    | -a <list> : Comma separated list of extra assets.
 -verbose   | -v        : Verbose output.
 -api_key               : Use api-key method to fetch article list.
 -canonical | -c        : Will include canonical links to original articles.
 -help      | -h        : Show this help.

Creates a local static copy of a DEV (dev.to) blog. Can specify a -target directory,
otherwise C<index.html> will be created at the current directory.

=cut

my %opt;
GetOptions(
    \%opt,
    'target|t=s',
    'user|u=s',
    'title=s',
    'assets|a=s',
    'verbose|v',
    'canonical|c',
    'api_key=s',
    'help|h',
);

pod2usage({-verbose => 1}) if $opt{help};
die '--username argument required' unless $opt{user};
my $target   = $opt{target} ||= '.';
my $blogname = $opt{title} || "$opt{user}'s blog";
my $dir      = path(__FILE__)->absolute->parent;
my $ua       = LWP::UserAgent->new();
my $acc_enc  = HTTP::Message::decodable;
my @assets   = qw/style.css favicon.png/;
push @assets, split(/,/, $opt{assets}) if $opt{assets};
$ua->default_header(
    'Accept'          => 'application/vnd.forem.api-v1+json',
    'Cache-Control'   => 'no-cache',
    'Pragma'          => 'no-cache',
    'User-Agent'      => 'Mozilla/5.0 Chrome/122.0.0.0 Safari/537.36',
    'Accept-Encoding' => $acc_enc,
);
$ua->default_header('api-key' => $opt{api_key}) if $opt{api_key};

# Create target dir and copy assets
$target =~ s#/$##;
path($target)->mkpath;
$dir->child($_)->copy(path($target)->child($_)) for @assets;

# Fetch articles from dev.to
my $api_url =
    $opt{api_key}
    ? 'https://dev.to/api/articles/me?per_page=1000'
    : "https://dev.to/api/articles?username=$opt{user}&per_page=1000";

my $response = $ua->get($api_url);
die "Failed to fetch posts: " . $response->status_line
    unless $response->is_success;

my $articles = decode_json($response->decoded_content);

# Build tag index and article list
my %tag_map;
foreach my $article (@$articles) {
    push @{ $tag_map{$_} }, $article for @{$article->{tag_list} || []};
}

# Generate tag pages
foreach my $tag (sort keys %tag_map) {
    my $tag_content = "<h1>#$tag</h1><div class='grid-container tag-grid'>";
    foreach my $article (@{ $tag_map{$tag} }) {
        my $title = $article->{title};
        my $slug  = $article->{slug};
        my $date  = published($article->{published_at});
        my $tags  = join(' ', map { "#$_" } @{$article->{tag_list} || []});
        my $cover_image =
            $article->{cover_image}
            ? "<img src='$article->{cover_image}' class='grid-cover borderless'>"
            : "";
        $tag_content .= "<div class='grid-item'><a href='$slug.html'>$cover_image
        <div class='grid-text'><h2 class='grid-title'>$title</h2><p class='meta'>$date</p>
        </div></a></div>";
    }
    $tag_content .= "</div><p>Tags: ";
    $tag_content .= $tag eq $_ ? "<b>#$_</b> " : "<a href='tag-$_.html'>#$_</a> "
        for sort keys %tag_map;
    $tag_content .= "</p><p><b><a href='index.html'>All articles</a></b></p>";
    render_html("#$tag", $tag_content, "tag-$tag.html");
}

# Generate index.html
my $index_content = "<h1>$blogname</h1><div class='grid-container'>";
foreach my $article (@$articles) {
    my $title = $article->{title};
    my $slug  = $article->{slug};
    my $tags  = render_tagline($article);
    my $cover_image =
        $article->{cover_image}
        ? "<img src='$article->{cover_image}' class='grid-cover borderless'>"
        : "";

    $index_content .= "<div class='grid-item'>
    <a href='$slug.html'>$cover_image
    <div class='grid-text'><h2 class='grid-title'>$title</h2>$tags</a>
    </div>";
}
$index_content .= "</div><p>Tags: ";
$index_content .= "<a href='tag-$_.html'>#$_</a> " for sort keys %tag_map;
render_html($blogname, "$index_content</p>", "index.html");

# Generate individual article pages
foreach my $article (@$articles) {
    my $url       = $article->{url};
    my $content   = fetch_article_content($article->{id});
    my $published = published($article->{published_at});

    my $cover_image =
        $article->{cover_image}
        ? "<img src='$article->{cover_image}' class='responsive-cover'>"
        : "";

    my $sidebar = "<div class='sidebar'><a href='index.html'>↑ Main Index</a><h2>Other Posts</h2><ul>";
    $sidebar .= render_li($_->{title}, $_->{id} == $article->{id} ? 0 : "$_->{slug}.html")
        for @$articles;
    $sidebar .= "</ul><h2>Tags</h2><ul>";
    $sidebar .= "<li><a href='tag-$_.html'>#$_</a></li>" for sort keys %tag_map;
    $sidebar .= "</ul></div>";

    my $tag_links = join(' ',
        map {"<a href='tag-$_.html'>#$_</a>"} @{$article->{tag_list} || []});

    my $post_content = "<div class='layout'>
    <div class='content'>$cover_image
    <div class='article'>
    <h1 class='post-title'>$article->{title}</h1>
    <p class='meta'>$published on <a href='$url'>dev.to</a> by $article->{user}->{name}</p>
    <p class='tags'>$tag_links</p>$content<br>
    <p><b>To see the comments or leave new ones, visit <a href='$url'>original article on DEV.to</a>.</b></p>
    </div></div>$sidebar</div>";
    render_html($article->{title}, $post_content, "$article->{slug}.html", $article->{canonical_url});
}

print "Site generated successfully!\n";

sub render_tagline {
    my $article = shift;
    my $date    = published($article->{published_at});
    my $tags    = join(' ', map { "#$_" } @{$article->{tag_list} || []});
    return "<p class='meta'>$date<br><span class='tags'>$tags</span></p></div>";
}

sub published {
    my $pub_time = shift;
    $pub_time =~ s/\.\d+Z/Z/;
    return localtime->strptime($pub_time, '%Y-%m-%dT%H:%M:%SZ')->strftime('Published: %b %d, %Y');
}

sub render_li {
    my $title = shift;
    my $url   = shift;
    my $html  = $url ? "<a href='$url'>$title</a>" : "<b>$title</b>";
    return "<li>$html</li>";
}

sub render_html {
    my $title    = shift;
    my $content  = shift;
    my $filename = shift;
    my $url      = shift;
    my $canon    = "";
    $canon  = "<link rel='canonical' href='$url'>" if $url && $opt{canonical};

    path("$target/$filename")->spew_utf8("<html>
        <head><meta charset='utf-8'>
        $canon<link rel='stylesheet' href='style.css'><link rel='icon' type='image/png' href='favicon.png'>
        <title>$title</title>
        <script src='https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.7.0/highlight.min.js'></script>
        <link rel='stylesheet' href='https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.7.0/styles/github-dark.min.css'>
        <script>hljs.highlightAll();</script>
        </head>
        <body>\n$content<footer class='site-footer'>
        <p>This is a static mirror of <a href='https://dev.to/$opt{user}'>my DEV blog</a>,
        created for wider accessibility using <a href='https://github.com/dkechag/dev_to_static'>dev_to_static</a>.</p>
        </footer>
        </body>\n</html>"
    );
    print "Created: $filename\n" if $opt{verbose};
}

sub fetch_article_content {
    my $article_id  = shift;
    my $article_res = $ua->get("https://dev.to/api/articles/$article_id");
    unless ($article_res->is_success) {
        warn "$article_id warn: $article_res->status_line\n";
        sleep 3;
        $article_res = $ua->get("https://dev.to/api/articles/$article_id");
        unless ($article_res->is_success) {
            warn "$article_id failure: $article_res->status_line\n";
            return "Failed to fetch article";
        }
    }

    my $article_data = decode_json($article_res->decoded_content);
    return $article_data->{body_html} || "Content not available";
}
