#!/usr/bin/env perl

use utf8;
use strict;
use warnings;
use LWP::UserAgent;
use JSON;
use Path::Tiny;
use Time::Piece;

my $target   = $ARGV[0] || '.';
my $username = 'your_dev_to_username';
my $blogname = "your_blog_name";
my $dir      = path(__FILE__)->absolute->parent;
my $api_url  = "https://dev.to/api/articles?username=$username";
my $ua       = LWP::UserAgent->new(agent => 'Mozilla/5.0 Chrome/122.0.0.0 Safari/537.36');
my @assets   = qw/style.css favicon.png/;

# Create target dir and copy assets
$target =~ s#/$##;
path($target)->mkpath;
$dir->child($_)->copy(path($target)->child($_)) for @assets;

# Fetch articles from dev.to
my $response = $ua->get($api_url);
die "Failed to fetch posts: " . $response->status_line unless $response->is_success;

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
    <p class='meta'>$published on <a href='$url'>DEV.to</a> by $article->{user}->{name}</p>
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
    my $canon    = shift || "";
    $canon  = "<link rel='canonical' href='$canon'>" if $canon;
    path("$target/$filename")->spew_utf8("<html>
        <head><meta charset='utf-8'>
        $canon<link rel='stylesheet' href='style.css'><link rel='icon' type='image/png' href='favicon.png'>
        <title>$title</title>
        <script src='https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.7.0/highlight.min.js'></script>
        <link rel='stylesheet' href='https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.7.0/styles/github-dark.min.css'>
        <script>hljs.highlightAll();</script>
        </head>
        <body>\n$content<footer class='site-footer'>
        <p>This is a static mirror of <a href='https://dev.to/$username'>my DEV.to blog</a>, created for wider accessibility.</p>
        </footer>
        </body>\n</html>"
    );
}

sub fetch_article_content {
    my $article_id  = shift;
    my $article_res = $ua->get("https://dev.to/api/articles/$article_id");
    return "Failed to fetch article" unless $article_res->is_success;

    my $article_data = decode_json($article_res->decoded_content);
    return $article_data->{body_html} || "Content not available";
}
