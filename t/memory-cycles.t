use strict;
use warnings;
use Test::More;
use Text::Amuse;
use File::Spec::Functions;
use Data::Dumper;
use File::Temp;

eval "use Test::Memory::Cycle";
if ($@) {
    plan skip_all => "Test::Memory::Cycle required for testing memory cycles";
    exit;
}
else {
    plan tests => 10;
}





my $document;
foreach my $file (qw/packing.muse
                     lists.muse
                     footnotes.muse/) {
    $document =
      Text::Amuse->new(file => catfile(t => testfiles => $file),
                       debug => 1);
    ok($document->as_html, "HTML produced");
    ok($document->as_latex, "LaTeX produced");
    memory_cycle_ok($document, "Memory cycles OK");
}

$document =
  Text::Amuse->new(file => catfile(t => testfiles => "recursiv.muse"));

diag $document->as_html;
diag $document->as_latex;
memory_cycle_ok($document, "Memory cycles OK");




