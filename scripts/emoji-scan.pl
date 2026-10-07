#!/usr/bin/perl
# P0-1 emoji scan. Portable across macOS BSD grep and GNU grep. No dependencies.
#
# Why not `grep -P`: BSD grep has no -P flag. It exits 2 with "invalid option -- P",
# so the gate looks green while scanning nothing at all. LC_ALL=C does NOT help --
# it changes locale, not the flag set. Byte-range matching under LC_ALL=C is worse:
# it false-positives on U+25B2 (the triangle this repo deliberately uses), because
# every 3-byte UTF-8 lead byte matches. Perl is the reliable option on macOS.
#
# Usage:  emoji-scan.pl            # scan git-tracked files
#         emoji-scan.pl FILE...    # scan specific files
# Exit:   0 = clean, 1 = hits found (so CI/`&&` chains fail loudly)
use strict; use warnings; use Encode ();
binmode(STDOUT, ':encoding(UTF-8)');

# 1F300-1F9FF pictographs, 1F000-1FAFF pictograph extensions, 2600-26FF misc
# symbols, 2700-27BF dingbats, FE0F variation selector (emoji presentation),
# 1F1E6-1F1FF regional indicators (flag sequences).
my $PAT = qr/[\x{1F300}-\x{1F9FF}\x{1F000}-\x{1FAFF}\x{2600}-\x{26FF}\x{2700}-\x{27BF}\x{FE0F}\x{1F1E6}-\x{1F1FF}]/;

my @files = @ARGV ? @ARGV : grep { !m{^dist/} } split /\n/, `git ls-files`;
@files = grep { -f $_ } @files;

my $hits = 0;
for my $file (@files) {
    open my $fh, '<:raw', $file or next;
    my $bytes = do { local $/; <$fh> };
    close $fh;
    next if !defined $bytes;
    # Skip binaries. They are not source, and trying to decode them is what makes
    # a naive scan die with "Malformed UTF-8 character" -- e.g. a tracked .png.
    next if $bytes =~ /[\x00-\x08\x0E-\x1A]/;
    my $text = eval { Encode::decode('UTF-8', $bytes, Encode::FB_CROAK()) };
    next if !defined $text;
    my $line = 0;
    for my $l (split /\n/, $text, -1) {
        $line++;
        next unless $l =~ $PAT;
        $hits++;
        print "HIT $file:$line: $l\n";
    }
}
print $hits ? "$hits hit(s)\n" : "clean\n";
exit($hits ? 1 : 0);
