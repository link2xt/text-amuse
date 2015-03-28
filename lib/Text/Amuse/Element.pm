package Text::Amuse::Element;
use strict;
use warnings;
use utf8;

=head1 NAME

Text::Amuse::Element - Helper for Text::Amuse

=head1 METHODS/ACCESSORS

Everything here is pretty much internal only, underdocumented and
subject to change.

=head3 new($string, previous => $previous_element)

Constructor. Accepts a string to be parsed, and an optional paired
list of arguments.

Accepted arguments: previous, with the previous element.

=cut

sub new {
    my ($class, $line, %args) = @_;
    # don't accept undefined values
    die "Missing input!" unless (defined $line);

    my $self = {
                rawline => $line,
                block => "",      # the block it says to belog
                type => "null", # the type
                string => "",      # the string
                removed => "", # the portion of the string removed

                # unclear if this should be weakened, but tests say
                # we're fine, because it's not circular. If there was
                # a ->next, then it should be weakened.
                previous => $args{previous},
               };
    bless $self, $class;
    # initialize it
    $self->_parse_string;
    # and finally assert that we didn't screw up
    my $origline = $self->rawline;
    my $test = $self->removed . $self->string;
    die "We screw up: <$origline> ne <$test>\n"
      if $origline ne $test;
    die "We screw up: input line <$line> ne rawline <$test>\n"
      if $line ne $test;
    die "We screw up: rawline <$origline> ne input line <$line>\n"
      if $origline ne $line;
    # and delete the previous, it is going to become obsolete after
    # the parsing.
    # delete $self->{previous};
    return $self;
}

=head3 previous

The previous object of the same class (if any).

=cut

sub previous {
    return shift->{previous};
}

=head3 rawline

Accessor to the raw input line

=cut

sub rawline {
    my $self = shift;
    return $self->{rawline};
}

sub _reset_rawline {
    my ($self, $line) = @_;
    $self->{rawline} = $line;
}

=head3 will_not_merge

Attribute to mark if an element cannot be further merged

=cut

sub will_not_merge {
    my ($self, $arg) = @_;
    if (defined $arg) {
        $self->{_will_not_merge} = $arg;
    }
    return $self->{_will_not_merge};
}

=head2 ACCESSORS

The following accessors set the value if an argument is provided. 

=head3 block

The block the string belongs

=cut

sub block {
    my $self = shift;
    if (@_) {
        $self->{block} = shift;
    }
    return $self->{block} || $self->type;
}

=head3 type

The type

=cut

sub type {
    my $self = shift;
    if (@_) {
        $self->{type} = shift;
    }
    return $self->{type};
}

=head3 string

The string (without the indentation or the leading markup)

=cut

sub string {
    my $self = shift;
    if (@_) {
        $self->{string} = shift;
    }
    return $self->{string};
}

=head3 removed

The portion of the string stripped out

=cut

sub removed {
    my $self = shift;
    if (@_) {
        $self->{removed} = shift;
    }
    return $self->{removed};
}

=head3 indentation

The indentation level, as a numerical value

=cut

sub indentation {
    my $self = shift;
    return length($self->removed);
}

sub _block_re {
    my $self = shift;
    return qr{(
                 biblio   |
                 play     |
                 comment  |
                 verse    |
                 center   |
                 right    |
                 example  |
                 quote    |
                 li | ul | ola | olA | oli | olI | oln # these are private
             )}x
}

sub _parse_string {
    my $self = shift;
    my $l = $self->rawline;
    my $blockre = $self->_block_re;
    # null line is default, do nothing
    if ($l =~ m/^[\n\t ]*$/s) {
        # do nothing, already default
        $self->removed($l);
        return;
    }
    if ($l =~ m!^(<($blockre)>\s*)$!s) {
        $self->type("startblock");
        $self->removed($1);
        $self->block($2);
        return;
    }
    if ($l =~ m!^(</($blockre)>\s*)$!s) {
        $self->type("stopblock");
        $self->removed($1);
        $self->block($2);
        return;
    }
    # headers
    if ($l =~ m!^((\*{1,5}) )(.+)$!s) {
        $self->type("h" . length($2));
        $self->removed($1);
        $self->string($3);
        return;
    }
    if ($l =~ m/^( +\- +)(.*)/s) {
        $self->type("li");
        $self->removed($1);
        $self->string($2);
        $self->block("ul");
        return;
    }
    if ($l =~ m/^(\s+  # leading space and type $1
                       (  # the type               $2
                           [0-9]+   |
                           [a-hA-H] |
                           [ixvIXV]+  |
                       )     
                       \. # a single dot
                       \s+)  # space
                   (.*) # the string itself $3
                  /sx) {
        $self->type("li");
        $self->removed($1);
        $self->string($3);
        my $list_type = $self->_identify_list_type($2); # this will set the type;
        $self->block($list_type);
        die "Something went wrong" if $self->type eq "null";
        return;
    }
    if ($l =~ m/^(\> )(.*)/s) {
        $self->string($2);
        $self->removed($1);
        $self->type("verse");
        return;
    }
    if ($l =~ m/^(\>)$/s) {
        $self->string("\n");
        $self->removed(">");
        $self->type("verse");
        return;
    }
    if ($l =~ m/^(\s+)/ and $l =~ m/\|/) {
        $self->type("table");
        $self->string($l);
        return;
    }
    if ($l =~ m/^(\; (.+))$/s) {
        $self->removed($l);
        $self->type("comment");
        return;
    }
    if ($l =~ m/^((\[[0-9]+\])\s+)(.+)$/s) {
        $self->type("footnote");
        $self->string($3);
        $self->removed($1);
        return;
    }
    if ($l =~ m/^((\s{6,})((\*\s?){5})\s*)$/s) {
        $self->type("newpage");
        $self->removed($2);
        $self->string($3);
        return;
    }
    if ($l =~ m/^( {20,})([^ ].+)$/s) {
        $self->block("right");
        $self->type("regular");
        $self->removed($1);
        $self->string($2);
        return;
    }
    if ($l =~ m/^( {6,})([^ ].+)$/s) {
        $self->block("center");
        $self->type("regular");
        $self->removed($1);
        $self->string($2);
        return;
    }
    if ($l =~ m/^( {2,})([^ ].+)$/s) {
        $self->block("quote");
        $self->type("regular");
        $self->removed($1);
        $self->string($2);
        return;
    }
    # anything else is regular
    $self->type("regular");
    $self->string($l);
    return;
}


sub _identify_list_type {
    my ($self, $list_type) = @_;
    my $type;
    if ($list_type =~ m/[0-9]/) {
        $type = "oln";
    } elsif ($list_type =~ m/[a-h]/) {
        $type = "ola";
    } elsif ($list_type =~ m/[A-H]/) {
        $type = "olA";
    } elsif ($list_type =~ m/[ixvl]/) {
        $type = "oli";
    } elsif ($list_type =~ m/[IXVL]/) {
        $type = "olI";
    } else {
        die "$type Unrecognized, fix your code\n";
    }
    return $type;
}

=head2 HELPERS

=head3 is_start_block($blockname)

Return true if the element is a "startblock" of the required block name

=cut

sub is_start_block {
    my $self = shift;
    my $block = shift || "";
    if ($self->type eq 'startblock' and $self->block eq $block) {
        return 1;
    } else {
        return 0;
    }
}

=head3 is_stop_block($blockname)

Return true if the element is a "stopblock" of the required block name

=cut

sub is_stop_block {
    my $self = shift;
    my $block = shift || "";
    if ($self->type eq 'stopblock' and $self->block eq $block) {
        return 1;
    } else {
        return 0;
    }
}

=head3 is_regular_maybe

Return true if the element is "regular", i.e., it just have trailing
white space

=cut

sub is_regular_maybe {
    my $self = shift;
    if ($self->type eq 'li' or
        $self->type eq 'null' or
        $self->type eq 'regular') {
        return 1;
    } else {
        return 0;
    }
}

=head3 can_merge_next 

Return true if the element will merge the next one

=cut

sub can_merge_next {
    my $self = shift;
    return 0 if $self->will_not_merge;
    if ($self->type eq 'stopblock'  or
        $self->type eq 'startblock' or
        $self->type eq 'null'       or
        $self->type eq 'table'      or
        $self->type eq 'newpage'    or
        $self->type eq 'comment') {
        return 0;
    } else {
        return 1;
    }
}

=head3 can_be_merged 

Return true if the element will merge the next one. Only regular strings.

=cut

sub can_be_merged {
    my $self = shift;
    return 0 if $self->will_not_merge;
    if ($self->type eq 'regular' or $self->type eq 'verse') {
        return 1;
    }
    else {
        return 0;
    }
}

=head3 can_be_in_list

Return true if the element can be inside a list

=cut 

sub can_be_in_list {
    my $self = shift;
    if ($self->type eq 'li' or
        $self->type eq 'null', or
        $self->type eq 'regular') {
        return 1;
    } else {
        return 0;
    }
}

=head3 can_be_regular

Return true if the element is quote, center, right

=cut

sub can_be_regular {
    my $self = shift;
    return 0 unless $self->type eq 'regular';
    if ($self->block eq 'quote' or
        $self->block eq 'center' or
        $self->block eq 'right') {
        return 1;
    }
    else {
        return 0;
    }
}


=head3 should_close_blocks

=cut

sub should_close_blocks {
    my $self = shift;
    return 0 if $self->type eq 'regular';
    return 1 if $self->type =~ m/h[1-5]/;
    return 1 if $self->block eq 'example';
    return 1 if $self->block eq 'verse';
    return 1 if $self->block eq 'table';
    return 1 if $self->type eq 'newpage';
    return 0;
}


=head3 add_to_string($string, $other_string, [...])

Append (just concatenate) the given strings to the string attribute.

=cut

sub add_to_string {
    my ($self, @args) = @_;
    my $orig = $self->string;
    $self->_reset_rawline(); # we modify the string, so throw away the rawline
    $self->string(join("", $orig, @args));
}

1;
