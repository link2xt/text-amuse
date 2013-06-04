#!/usr/bin/env perl

# This program is free software and is published under the same terms
# as Perl itself.

# written by Marco Pessotto <melmothx@gmail.com>

use strict;
use warnings;
use utf8;
use Text::Amuse;
use Template::Tiny;
use EBook::EPUB;
use Cwd;
use Getopt::Long;
use File::Basename;
use Data::UUID;
use File::Temp;
use Data::Dumper;

# quick and dirty to get the stuff compiled

my $xtx = 0;
my $help;
GetOptions (
            xtx => \$xtx,
            help => \$help,
            version => \$help,
           );

if ($help) {
    print << "HELP";
Usage: muse-quick.pl [-xtx] file.muse

Version $Text::Amuse::VERSION.

This program uses Text::Amuse to produce usable output in HTML, EPUB,
LaTeX and PDF format.

The only option, beside --help, is --xtx, which uses XeLaTeX instead
of pdfLaTeX to generate the PDF output.

HELP
    exit;
}

my $tt = Template::Tiny->new();

foreach my $file (@ARGV) {
    unless ($file =~ m/\.muse$/ and -f $file) {
        warn "Skipping $file";
        next;
    }
    make_html($file);
    make_latex($file);
    make_epub($file);
}

sub css_template {
    my $css = <<'EOF';

html,body {
	margin:0;
	padding:0;
	border: none;
 	background: transparent;
	font-family: serif;
	font-size: 10pt;
} 
div#page {
   margin:20px;
   padding:20px;
}
pre, code {
    font-family: Consolas, courier, monospace;
}
/* invisibles */
span.hiddenindex, span.commentmarker, .comment, span.tocprefix, #hitme {
    display: none
}

h1 { 
    font-size: 200%;
    margin: .67em 0
}
h2 { 
    font-size: 180%;
    margin: .75em 0
}
h3 { 
    font-size: 150%;
    margin: .83em 0
}
h4 { 
    font-size: 130%;
    margin: 1.12em 0
}
h5 { 
    font-size: 115%;
    margin: 1.5em 0
}
h6 { 
    font-size: 100%;
    margin: 0;
}

sup, sub {
    font-size: 8pt;
    line-height: 0;
}

/* invisibles */
span.hiddenindex, span.commentmarker, .comment, span.tocprefix, #hitme {
    display: none
}

.comment {
    background: rgb(255,255,158);
}

.verse {          
    margin: 24px 48px;
    overflow: auto;
} 

table, th, td {
    border: solid 1px black;
    border-collapse: collapse;
}
td, th {
    padding: 2px 5px;
}

hr {
    margin: 24px 0;
    color: #000;
    height: 1px;
    background-color: #000;
}

table {
    margin: 24px auto;
}

td, th { vertical-align: top; }
th {font-weight: bold;}

caption {
    caption-side:bottom;
}

img.embedimg {
    margin: 1em;
    max-width:90%;
}
div.image {
    margin: 1em;
    text-align: center;
    padding: 3px;
    background-color: white;
}

.biblio p, .play p {
  margin-left: 1em;
  text-indent: -1em;
}

div.biblio, div.play {
  padding: 24px 0;
}

div.caption {
    padding-bottom: 1em;
}

div.center {
    text-align: center;
}

div.right {
    text-align: right;
}

div#tableofcontents{
    padding:20px;
}

#tableofcontents p {
    margin: 3px 1em;
    text-indent: -1em;
}

.toclevel1 {
	font-weight: bold;
	font-size:11pt
}	

.toclevel2 {
	font-weight: bold;
	font-size: 10pt;
}

.toclevel3 {
	font-weight: normal;
	font-size: 9pt;
}

.toclevel4 {
	font-weight: normal;
	font-size: 8pt;
}
EOF
    return $css;
}


sub html_template {
    my $html = <<'EOF';
<!doctype html>
<html>
<head>
<meta charset="UTF-8">
<title>[% doc.header_as_html.title %]</title>
    <style type="text/css">
 <!--/*--><![CDATA[/*><!--*/
[% css %]
  /*]]>*/-->
    </style>
</head>
<body>
 <div id="page">
  [% IF doc.header_as_html.author %]
  <h2>[% doc.header_as_html.author %]</h2>
  [% END %]
  <h1>[% doc.header_as_html.title %]</h1>

  [% IF doc.header_as_html.source %]
  [% doc.header_as_html.source %]
  [% END %]

  [% IF doc.header_as_html.notes %]
  [% doc.header_as_html.notes %]
  [% END %]

  [% IF doc.toc_as_html %]
  <div class="header">
  [% doc.toc_as_html %]
  </div>
  [% END %]

 <div id="thework">

[% doc.as_html %]

 </div>
</div>
</body>
</html>

EOF
    return \$html;
}

sub minimal_html_template {
    my $html = <<'EOF';
<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <title>[% title %]</title>
    <link href="stylesheet.css" type="text/css" rel="stylesheet" />
  </head>
  <body>
    <div id="page">
      [% text %]
    </div>
  </body>
</html>
EOF
    return \$html;
}


sub make_html {
    my $file = shift;
    my $doc = Text::Amuse->new(file => $file);
    my $out = "";
    my $in = html_template();
    $tt->process($in, {
                       doc => $doc,
                       css => css_template(),
                      }, \$out);
    my $outfile = $file;
    $outfile =~ s/muse$/html/;
    open (my $fh, ">:encoding(utf-8)", $outfile);
    print $fh $out;
    close $fh;
}

sub latex_template {
    my $latex = <<'EOF';
\documentclass[DIV=9,fontsize=10pt,oneside,paper=a5]{[% IF doc.wants_toc %]scrbook[% ELSE %]scrartcl[% END %]}
[% IF xtx %]
\usepackage{fontspec}
\usepackage{polyglossia}
\setmainfont[Mapping=tex-text]{Charis SIL}
\setsansfont[Mapping=tex-text,Scale=MatchLowercase]{DejaVu Sans}
\setmonofont[Mapping=tex-text,Scale=MatchLowercase]{DejaVu Sans Mono}
\setmainlanguage{[% doc.language %]}
[% ELSE %]
\usepackage[[% doc.language %]]{babel}
\usepackage[utf8x]{inputenc}
\usepackage[T1]{fontenc}
\usepackage{lmodern}
[% END %]
\usepackage{microtype} % you need an *updated* texlive 2012, but harmless
\usepackage{graphicx}
\usepackage{alltt}
\usepackage{verbatim}
% http://tex.stackexchange.com/questions/3033/forcing-linebreaks-in-url
\PassOptionsToPackage{hyphens}{url}\usepackage[hyperfootnotes=false,hidelinks,breaklinks=true]{hyperref}
\usepackage{bookmark}
\usepackage[stable]{footmisc}
\usepackage{enumerate}
\usepackage{tabularx}
\usepackage[normalem]{ulem}
% remove the numbering
\setcounter{secnumdepth}{-2}


% avoid breakage on multiple <br><br> and avoid the next [] to be eaten
\newcommand*{\forcelinebreak}{~\\\relax}

\newcommand*{\hairline}{%
  \bigskip%
  \noindent \hrulefill%
  \bigskip%
}

% reverse indentation for biblio and play

\newenvironment*{amusebiblio}{
  \leftskip=\parindent
  \parindent=-\parindent
  \bigskip
  \indent
}{\bigskip}

\newenvironment*{amuseplay}{
  \leftskip=\parindent
  \parindent=-\parindent
  \bigskip
  \indent
}{\bigskip}

\newcommand*{\Slash}{\slash\hspace{0pt}}

% global style
\pagestyle{plain}
\addtokomafont{disposition}{\rmfamily}
% forbid widows/orphans
\clubpenalty=10000
\widowpenalty=10000
\frenchspacing
\sloppy

\title{[% doc.header_as_latex.title %]}
\date{[% doc.header_as_latex.date %]}
\author{[% doc.header_as_latex.author %]}
\begin{document}
\maketitle

[% IF doc.wants_toc %]

\tableofcontents
\cleardoublepage

[% END %]

[% doc.as_latex %]

\cleardoublepage

\thispagestyle{empty}
\strut
\vfill

\begin{center}

[% doc.header_as_latex.source %]

[% doc.header_as_latex.notes %]

\end{center}

\end{document}

EOF
    return \$latex;
}

sub make_latex {
    my $file = shift;
    my $doc = Text::Amuse->new(file => $file);
    my $in = latex_template();
    my $out = "";
    $tt->process($in, { doc => $doc, xtx => $xtx }, \$out);
    my $outfile = $file;
    $outfile =~ s/muse$/tex/;
    open (my $fh, ">:encoding(utf-8)", $outfile);
    print $fh $out;
    close $fh;
    my $exec = "pdflatex";
    if ($xtx) {
        $exec = "xelatex";
    }
    my $base = $file;
    $base =~ s/muse$//;
    cleanup($base);
    for (1..3) {
        system($exec, '-interaction=nonstopmode', $outfile);
    }
    cleanup($base);
}

sub cleanup {
    my $base = shift;
    return unless $base;
    for (qw/aux toc tuc/) {
        my $remove = $base . $_;
        if (-f $remove) {
            unlink $remove;
            print "removing $remove\n";
        }
    }
}

sub make_epub {
    my $file = shift;
    my ($name, $path, $suffix) = fileparse($file, ".muse");
    my $cwd = getcwd;
    my $epubname = "${name}.epub";
    if ($path) {
        chdir $path or die "Couldn't chdir into $path $!";
    }
    my $epub = EBook::EPUB->new;
    my $text = Text::Amuse->new(file => $file);

    my @toc = $text->raw_html_toc;
    my @pieces = $text->as_splat_html;
    my $missing = scalar(@pieces) - scalar(@toc);
    # this shouldn't happen

    if ($missing > 1 or $missing < 0) {
        print Dumper(\@pieces), Dumper(\@toc);
        die "This shouldn't happen: missing pieces: $missing";
    }
    if ($missing == 1) {
        unshift @toc, {
                       index => 0,
                       level => 0,
                       string => "start body",
                      };
    }


    my $tempdir = File::Temp->newdir();
    $epub->add_stylesheet("stylesheet.css" => css_template());

    my $titlepage;
    my $header = $text->header_as_html;
    if (my $t = $header->{title}) {
        $epub->add_title(_remove_html_tags($t));
        $titlepage .= "<h1>$t</h1>\n";
    }
    else {
        $epub->add_title(_remove_html_tags($t) || "No title");
    }
    if (my $author = $header->{author}) {
        $epub->add_author(_remove_html_tags($author));
        $titlepage .= "<h2>$author</h2>\n";
    }
    if ($header->{date}) {
        if ($header->{date} =~ m/([0-9]{4})/) {
            $epub->add_date($1);
            $titlepage .= "<h3>$header->{date}</h3>"
        }
    }
    $epub->add_language($text->language_code);
    if (my $source = $header->{source}) {
        $epub->add_source($source);
        $titlepage .= "<p>$source</p>";
    }
    if (my $notes = $header->{notes}) {
        $epub->add_description($notes);
        $titlepage .= "<p>$notes</p>";
    }
    my $in = minimal_html_template;
    my $out = "";
    $tt->process($in, {
                       title => _remove_html_tags($header->{title}),
                       text => $titlepage
                      }, \$out);
    my $tpid = $epub->add_xhtml("titlepage.xhtml", $out);
    my $order = 0;
    $epub->add_navpoint(label => "titlepage",
                        id => $tpid,
                        content => "titlepage.xhtml",
                        play_order => ++$order);

    foreach my $fi (@pieces) {
        my $index = shift(@toc);
        my $xhtml = "";
        # print Dumper($index);
        my $filename = "piece" . $index->{index};
        my $title = "*" x $index->{level} . " " . $index->{string};
        $tt->process($in, { title => _remove_html_tags($title),
                            text => $fi },
                     \$xhtml);
        my $id = $epub->add_xhtml($filename, $xhtml);
        $epub->add_navpoint(label => $index->{string},
                            content => $filename,
                            id => $id,
                            play_order => ++$order);
    }
    foreach my $att ($text->attachments) {
        die "$att doesn't exist!" unless -f $att;
        my $mime; 
        if ($att =~ m/\.jpe?g$/) {
            $mime = "image/jpeg";
        }
        elsif ($att =~ m/\.png$/) {
            $mime = "image/png";
        }
        else {
            die "Unrecognized attachment $att!";
        }
        $epub->copy_file($att, $att, $mime);
    }
    $epub->pack_zip($epubname);
    chdir $cwd or die "Couldn't chdir into $cwd: $!";
}

sub _remove_html_tags {
    my $string = shift;
    return "" unless defined $string;
    $string =~ s/<.+?>//g;
    return $string;
}
