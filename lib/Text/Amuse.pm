package Text::Amuse;

use 5.010001;
use strict;
use warnings;
# use Data::Dumper;
use Text::Amuse::Document;
use Text::Amuse::Output;
use Text::Amuse::Beamer;

=head1 NAME

Text::Amuse - Perl module to generate HTML and LaTeX documents from Emacs Muse markup.

=head1 VERSION

Version 0.43

=cut

our $VERSION = '0.43';


=head1 SYNOPSIS

Typical usage which should illustrate all the public methods

    use Text::Amuse;
    my $doc = Text::Amuse->new(file => "test.muse");
    
    # get the title, author, etc. as an hashref
    my $html_directives = $doc->header_as_html;
    
    # get the table of contents
    my $html_toc = $doc->toc_as_html;
    
    # get the body
    my $html_body = $doc->as_html;
    
    # same for LaTeX
    my $latex_directives = $doc->header_as_latex;
    my $latex_body = $doc->as_latex;
    
    # do we need a \tableofcontents ?
    my $wants_toc = $doc->wants_toc; # (boolean)
    
    # files attached
    my @images = $doc->attachments;
    
    # at this point you can inject the values in a template, which is left
    # to the user. See the bundled muse-quick.pl for a real-life usage.
    

=head1 CONSTRUCTOR

=head3 new (file => $file)

Create a new Text::Amuse object. You should pass the named parameter
C<file>, pointing to a muse file to process. Please note that you
can't pass a string. Build a wrapper going through a temporary file if
you need to pass strings.

Optionally, accept a C<partial> option pointing to an arrayref of
integers, meaning that only those chunks will be needed.

The beamer output doesn't take C<partial> in account.

=cut

sub new {
    my $class = shift;
    my %opts = @_;
    my $self = {
                file => $opts{file},
                debug => $opts{debug},
                partials => undef,
               };
    if (my $chunks = $opts{partial}) {
        die "partial needs an arrayref" unless ref($chunks) eq 'ARRAY';
        my %partials;
        foreach my $chunk (@$chunks) {
            if ($chunk and $chunk =~ m/\A([0-9]|[1-9][0-9]+)\z/) {
                $partials{$1} = 1;
            }
            else {
                die "Partials should be integers";
            }
        }
        if (%partials) {
            $self->{partials} = \%partials;
        }
    }

    $self->{_document_obj} =
      Text::Amuse::Document->new(file => $self->{file},
                                 debug => $self->{debug});
    bless $self, $class;
}

=head3 document

Accessor to the L<Text::Amuse::Document> object. [Internal]

=head3 file

Accessor to the file passed in the constructor (read-only)

=head3 partials

Return an hashref where the keys are the chunk indexes and the values
are true, undef otherwise.

=cut

sub document {
    return shift->{_document_obj};
}

sub partials {
    my $self = shift;
    if (my $partials = $self->{partials}) {
        return { %$partials };
    }
    else {
        return undef;
    }
}

sub file {
    return shift->{file};
}


=head2 HTML output

=head3 as_html

Output the HTML document (and cache it in the object)

=cut

sub _html_obj {
    my $self = shift;
    unless (defined $self->{_html_doc}) {
        $self->{_html_doc} =
          Text::Amuse::Output->new(
                                   document => $self->document,
                                   format => 'html',
                                  );
    }
    return $self->{_html_doc};
}

sub _get_body {
    my ($self, $doc, $split) = @_;
    if (my $partials = $self->partials) {
        my @chunks = @{ $doc->process(split => 1) };
        my @out;
        for (my $i = 0; $i < @chunks; $i++) {
            push @out, $chunks[$i] if $partials->{$i};
        }
        return \@out;
    }
    else {
        return $doc->process(split => $split);
    }
}

sub _get_full_body {
    my ($self, $doc) = @_;
    return $self->_get_body($doc => 0);
}

sub _get_splat_body {
    my ($self, $doc) = @_;
    return $self->_get_body($doc => 1);
}


sub as_html {
    my $self = shift;
    unless (defined $self->{_html_output_strings}) {
        $self->{_html_output_strings} = $self->_get_full_body($self->_html_obj);
    }
    return unless defined wantarray;
    return join("", @{ $self->{_html_output_strings} });
}

=head3 header_as_html

The directives of the document in HTML (title, authors, etc.),
returned as an hashref.

B<Please note that the keys are not escaped nor manipulated>.

=cut

sub header_as_html {
    my $self = shift;
    $self->as_html; # trigger the html generation. This operation is
                    # not expensive if we already call it, and won't
                    # be the next time.
    unless (defined $self->{_cached_html_header}) {
        $self->{_cached_html_header} = $self->_html_obj->header;
    }
    return { %{ $self->{_cached_html_header} } };
}

=head3 toc_as_html

Return the HTML formatted ToC, as a string.

=cut

sub toc_as_html {
    my $self = shift;
    $self->as_html; # be sure that it's processed
    return $self->_html_obj->html_toc;
}

=head3 as_splat_html

Return a list of strings, each of them is a html page resulting from
the splitting of the as_html output. Linked footnotes as inserted at
the end of each page.

=cut

sub as_splat_html {
    my $self = shift;
    return @{ $self->_get_splat_body($self->_html_obj) };
}


=head3 raw_html_toc

Return an internal representation of the ToC

=cut

sub raw_html_toc {
    my $self = shift;
    $self->as_html;
    return $self->_html_obj->table_of_contents;
}



=head2 LaTeX output

=head3 as_latex

Output the (Xe)LaTeX document (and cache it in the object), as a
string.

=cut

sub _latex_obj {
    my $self = shift;
    unless (defined $self->{_ltx_doc}) {
        $self->{_ltx_doc} =
          Text::Amuse::Output->new(
                                   document => $self->document,
                                   format => 'ltx',
                                  );
    }
    return $self->{_ltx_doc};
}

=head3 as_splat_latex

Return a list of strings, each of them is a latex chunk resulting from
the splitting of the as_latex output.

=cut

sub as_latex {
    my $self = shift;
    unless (defined $self->{_latex_output_strings}) {
        $self->{_latex_output_strings} = $self->_get_full_body($self->_latex_obj);
    }
    return unless defined wantarray;
    return join("", @{ $self->{_latex_output_strings} });
}

sub as_splat_latex {
    my $self = shift;
    return @{ $self->_get_splat_body($self->_latex_obj) };
}

=head3 as_beamer

Output the document as LaTeX, but wrap each section which doesn't
contain a comment C<; noslide> inside a frame.

=cut

sub as_beamer {
    my $self = shift;
    my $latex = $self->_latex_obj->process;
    return Text::Amuse::Beamer->new(latex => $latex)->process;
}

=head3 wants_toc

Return true if a toc is needed because we found some headings inside.

=cut

sub wants_toc {
    my $self = shift;
    $self->as_latex;
    my @toc = $self->_latex_obj->table_of_contents;
    return scalar(@toc);
}


=head3 header_as_latex

The LaTeX formatted header, as an hashref. Keys are not interpolated
in any way.

=cut

sub header_as_latex {
    my $self = shift;
    $self->as_latex;
    unless (defined $self->{_cached_latex_header}) {
        $self->{_cached_latex_header} = $self->_latex_obj->header;
    }
    return { %{ $self->{_cached_latex_header} } };
}

=head2 Helpers

=head3 attachments

Report the attachments (images) found, as a list. This can be invoked
only after a call (direct or indirect) to C<as_html> or C<as_latex>,
or any other operation which scans the body, otherwise you'll get an
empty list.

=cut

sub attachments {
    my $self = shift;
    return $self->document->attachments;
}

=head3 language_code

The language code of the document. This method will looks into the
header of the document, searching for the keys C<lang> or C<language>,
defaulting to C<en>.

=head3 language

Same as above, but returns the human readable version, notably used by
Babel, Polyglossia, etc.

=cut

sub _language_mapping {
    my $self = shift;
    return {
            cs => 'czech',
            de => 'german',
            en => 'english',
            es => 'spanish',
            fi => 'finnish',
            fr => 'french',
            hr => 'croatian',
            it => 'italian',
            sr => 'serbian',
            ru => 'russian',
            nl => 'dutch',
            pt => 'portuges',
            tr => 'turkish',
            mk => 'macedonian',
            sv => 'swedish',
            pl => 'polish',
           };
}


=head3 header_defined

Return a convenience hashref with the header fields set to true when
they are defined in the document.

This way, in the template you can write doc.header_defined.subtitle
without doing crazy things like C<doc.header_as_html.subtitle.size>
which relies on virtual methods.

=cut

sub header_defined {
    my $self = shift;
    unless (defined $self->{_header_defined_hashref}) {
        my %fields;
        my %header = $self->document->raw_header;
        foreach my $k (keys %header) {
            if (defined($header{$k}) and length($header{$k})) {
                $fields{$k} = 1;
            }
        }
        $self->{_header_defined_hashref} = \%fields;
    }
    return { %{ $self->{_header_defined_hashref} } };
}


sub language_code {
    my $self = shift;
    unless (defined $self->{_doc_language_code}) {
        my %header = $self->document->raw_header;
        my $lang = $header{lang} || $header{language} || "en";
        my $real = "en";
        # check if language exists;
        if ($self->_language_mapping->{$lang}) {
            $real = $lang;
        }
        $self->{_doc_language_code} = $real;
    }
    return $self->{_doc_language_code};
}

sub language {
    my $self = shift;
    unless (defined $self->{_doc_language}) {
        my $lc = $self->language_code;
        # guaranteed not to return undef
        $self->{_doc_language} = $self->_language_mapping->{$lc};
    }
    return $self->{_doc_language};
}

=head3 other_language_codes

Always return undef, because in the current implementation you can't
switch language in the middle of a text. But could be implemented in
the future. It should return an arrayref or undef.

=cut

sub other_language_codes {
    return;
}

=head3 other_languages

Always return undef. When and if implemented, it should return an
arrayref or undef.

=cut


sub other_languages {
    return;
}

=head3 hyphenation

Return a validated version of the C<#hyphenation> header, if present,
or the empty string.

=cut

sub hyphenation {
    my $self = shift;
    unless (defined $self->{_doc_hyphenation}) {
        my %header = $self->document->raw_header;
        my $hyphenation = $header{hyphenation} || '';
        my @patterns = split(/\s+/, $hyphenation);
        my @validated;
        foreach my $pattern (@patterns) {
            if ($pattern =~ m/\A(
                                  [[:alpha:]]+
                                  (-[[:alpha:]]+)*
                              )\z/x) {
                push @validated, $1;
            }
        }
        my $valid = '';
        if (@validated) {
            $valid = join(' ', @validated);
        }
        $self->{_doc_hyphenation} = $valid;
    }
    return $self->{_doc_hyphenation};
}


=head1 DIFFERENCES WITH THE ORIGINAL EMACS MUSE MARKUP

The updated manual can be found at
L<http://www.amusewiki.org/library/manual> and is also present between
the test files (C<t/testfiles/manual.muse>), even if is just seldom
updated.

=head3 Inline markup

Underlining has been dropped.

Emphasis and strong can also be written with tags, like <em>emphasis</em>,
<strong>strong</strong> and <code>code</code>.

Added tag <sup> and <sub> for superscript and subscript.

=head3 Block markup

The only tables supported are the native one (with ||| as separator).

=head3 Others

Anchors are unsupported (mainly because of the confusing syntax and
the PDF output).

Embedded lisp code and syntax highlight is not supported.

Exoteric stuff like citing from other resources is not supported.

The scope of this module is not to replicate all the features of the
original implementation, but to use the markup for a wiki (as opposed
as a personal and private wiki).

=head1 AUTHOR

Marco Pessotto, C<< <melmothx at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to the author's email or
just use the CPAN's RT. If you find a bug, please provide a minimal
muse file which reproduces the problem (so I can add it to the test
suite).

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Text::Amuse

Repository available at Github: L<https://github.com/melmothx/text-amuse>

=head1 SEE ALSO

The original documentation for the Emacs Muse markup can be found at:
L<http://mwolson.org/static/doc/muse/Markup-Rules.html>

=head1 LICENSE

This module is free software and is published under the same terms as
Perl itself.

=cut

1; # End of Text::Amuse
